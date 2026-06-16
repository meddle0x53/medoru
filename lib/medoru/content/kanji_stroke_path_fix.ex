defmodule Medoru.Content.KanjiStrokePathFix do
  @moduledoc """
  Normalizes kanji stroke paths so the client-side parser can read them correctly.

  The drawing hook in `assets/js/hooks/kanji_writing.js` only consumes a single
  segment per SVG command. KanjiVG-style paths sometimes chain multiple segments
  after one `c`/`C` command, which makes the parser see only the first segment.
  The result is a very short expected stroke, so even a perfectly drawn stroke
  is rejected.

  This fix expands those chained segments into explicit per-segment commands,
  e.g. `M ... c seg1 seg2 seg3` becomes `M ... c seg1 c seg2 c seg3`.

  Run in a release console or `mix run`:

      Medoru.Content.KanjiStrokePathFix.apply()

  Or target one kanji:

      Medoru.Content.KanjiStrokePathFix.apply_for("60fca40e-5e56-4ac2-bbbf-a059b701f5a1")
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji

  import Ecto.Query
  require Logger

  @doc """
  Apply the normalization to all kanji with stroke data.
  Returns {:ok, count} where count is the number of kanji updated.
  """
  def apply do
    kanji = Repo.all(from k in Kanji, where: not is_nil(k.stroke_data))

    {updated, errors} =
      Enum.reduce(kanji, {0, []}, fn k, {updated, errors} ->
        case fix_kanji(k) do
          {:ok, :changed} -> {updated + 1, errors}
          {:ok, :unchanged} -> {updated, errors}
          {:error, reason} -> {updated, ["#{k.character} (#{k.id}): #{reason}" | errors]}
        end
      end)

    if errors != [] do
      Logger.warning("KanjiStrokePathFix encountered #{length(errors)} errors")
      Enum.each(errors, &Logger.warning/1)
    end

    Logger.info("KanjiStrokePathFix updated #{updated} kanji")
    {:ok, updated}
  end

  @doc """
  Apply the normalization to a single kanji by id.
  """
  def apply_for(id) when is_binary(id) do
    case Repo.get(Kanji, id) do
      nil ->
        {:error, :not_found}

      kanji ->
        fix_kanji(kanji)
    end
  end

  defp fix_kanji(%Kanji{stroke_data: nil}), do: {:ok, :unchanged}

  defp fix_kanji(%Kanji{} = kanji) do
    strokes = kanji.stroke_data["strokes"] || []

    {new_strokes, changed?} =
      Enum.map_reduce(strokes, false, fn stroke, changed? ->
        path = stroke["path"]

        if is_binary(path) and needs_normalization?(path) do
          normalized = normalize_path(path)
          {Map.put(stroke, "path", normalized), true}
        else
          {stroke, changed?}
        end
      end)

    if changed? do
      new_data = Map.put(kanji.stroke_data, "strokes", new_strokes)

      kanji
      |> Ecto.Changeset.change(stroke_data: new_data)
      |> Repo.update()
      |> case do
        {:ok, _} -> {:ok, :changed}
        {:error, changeset} -> {:error, inspect(changeset.errors)}
      end
    else
      {:ok, :unchanged}
    end
  end

  @doc """
  Returns true if a path contains SVG command chaining that the client parser
  cannot handle. The parser only consumes a single segment per command, so
  paths with more numbers than a single segment expects need to be expanded.
  """
  def needs_normalization?(path) when is_binary(path) do
    tokenize(path)
    |> needs_normalization_tokens?()
  end

  def needs_normalization?(_), do: false

  defp needs_normalization_tokens?([]), do: false

  defp needs_normalization_tokens?([{:cmd, cmd} | rest]) do
    type = String.upcase(cmd)
    count = param_count(type)

    numbers =
      Enum.take_while(rest, fn
        {:num, _} -> true
        _ -> false
      end)

    # M/m can take multiple coordinate pairs (implicit lineto) and the parser
    # already handles them, so we don't flag it as needing normalization.
    if type not in ["M", "Z"] and length(numbers) > count do
      true
    else
      needs_normalization_tokens?(Enum.drop(rest, length(numbers)))
    end
  end

  defp needs_normalization_tokens?([_ | rest]), do: needs_normalization_tokens?(rest)

  defp param_count("M"), do: 2
  defp param_count("L"), do: 2
  defp param_count("H"), do: 1
  defp param_count("V"), do: 1
  defp param_count("C"), do: 6
  defp param_count("S"), do: 4
  defp param_count("Q"), do: 4
  defp param_count("T"), do: 2
  defp param_count("A"), do: 7
  defp param_count("Z"), do: 0
  defp param_count(_), do: 0

  @doc """
  Normalizes an SVG path by expanding chained command segments into explicit
  per-segment commands.
  """
  def normalize_path(path) when is_binary(path) do
    tokens = tokenize(path)
    {output, _} = process_tokens(tokens, [], nil, {0.0, 0.0})
    Enum.join(output, " ")
  end

  # Tokenize into commands and numbers, preserving order.
  defp tokenize(path) do
    ~r/([A-Za-z])|(-?\d*\.?\d+(?:[eE][+-]?\d+)?)/
    |> Regex.scan(path)
    |> Enum.map(fn
      [_full, cmd] when cmd != "" and cmd != nil -> {:cmd, cmd}
      [_full, "", num] -> {:num, parse_number(num)}
    end)
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> String.to_integer(str) * 1.0
    end
  end

  # Process tokens recursively. State carries output list, pending command,
  # and current point.
  defp process_tokens([], output, _pending_cmd, _point), do: {Enum.reverse(output), nil}

  defp process_tokens([{:cmd, cmd} | rest], output, _pending_cmd, point) do
    process_tokens(rest, output, cmd, point)
  end

  defp process_tokens([{:num, _} | rest], output, nil, point) do
    # Numbers without a pending command shouldn't happen in valid SVG.
    # Skip them to avoid crashing.
    process_tokens(rest, output, nil, point)
  end

  defp process_tokens(tokens, output, pending_cmd, {cx, cy} = point) do
    type = String.upcase(pending_cmd)
    relative = pending_cmd != type

    case type do
      "M" ->
        case take_numbers(tokens, 2) do
          {:ok, [x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y
            out_x = if relative, do: x, else: nx
            out_y = if relative, do: y, else: ny

            out_entry = "#{pending_cmd} #{fmt(out_x)},#{fmt(out_y)}"
            new_output = [out_entry | output]

            # Subsequent coordinate pairs after M are treated as implicit lineto.
            case rest do
              [{:num, _} | _] ->
                lineto_cmd = if pending_cmd == String.upcase(pending_cmd), do: "L", else: "l"
                process_tokens(rest, new_output, lineto_cmd, {nx, ny})

              _ ->
                process_tokens(rest, new_output, nil, {nx, ny})
            end

          :error ->
            {output, point}
        end

      "L" ->
        case take_numbers(tokens, 2) do
          {:ok, [x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y
            out_entry = "#{pending_cmd} #{fmt(x)},#{fmt(y)}"
            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "H" ->
        case take_numbers(tokens, 1) do
          {:ok, [x], rest} ->
            nx = if relative, do: cx + x, else: x
            out_entry = "#{pending_cmd} #{fmt(x)}"
            process_tokens(rest, [out_entry | output], pending_cmd, {nx, cy})

          :error ->
            {output, point}
        end

      "V" ->
        case take_numbers(tokens, 1) do
          {:ok, [y], rest} ->
            ny = if relative, do: cy + y, else: y
            out_entry = "#{pending_cmd} #{fmt(y)}"
            process_tokens(rest, [out_entry | output], pending_cmd, {cx, ny})

          :error ->
            {output, point}
        end

      "C" ->
        case take_numbers(tokens, 6) do
          {:ok, [cp1x, cp1y, cp2x, cp2y, x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y

            out_entry =
              "#{pending_cmd} #{fmt(cp1x)},#{fmt(cp1y)} #{fmt(cp2x)},#{fmt(cp2y)} #{fmt(x)},#{fmt(y)}"

            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "S" ->
        case take_numbers(tokens, 4) do
          {:ok, [cp2x, cp2y, x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y

            out_entry =
              "#{pending_cmd} #{fmt(cp2x)},#{fmt(cp2y)} #{fmt(x)},#{fmt(y)}"

            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "Q" ->
        case take_numbers(tokens, 4) do
          {:ok, [cpx, cpy, x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y

            out_entry =
              "#{pending_cmd} #{fmt(cpx)},#{fmt(cpy)} #{fmt(x)},#{fmt(y)}"

            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "T" ->
        case take_numbers(tokens, 2) do
          {:ok, [x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y
            out_entry = "#{pending_cmd} #{fmt(x)},#{fmt(y)}"
            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "A" ->
        case take_numbers(tokens, 7) do
          {:ok, [rx, ry, rotation, large_arc, sweep, x, y], rest} ->
            nx = if relative, do: cx + x, else: x
            ny = if relative, do: cy + y, else: y

            out_entry =
              "#{pending_cmd} #{fmt(rx)} #{fmt(ry)} #{fmt(rotation)} #{trunc(large_arc)} #{trunc(sweep)} #{fmt(x)},#{fmt(y)}"

            process_tokens(rest, [out_entry | output], pending_cmd, {nx, ny})

          :error ->
            {output, point}
        end

      "Z" ->
        process_tokens(tokens, ["Z" | output], nil, point)

      _ ->
        # Unknown command: stop processing.
        {output, point}
    end
  end

  defp take_numbers(tokens, count), do: take_numbers(tokens, count, [])

  defp take_numbers(tokens, 0, acc), do: {:ok, Enum.reverse(acc), tokens}

  defp take_numbers([{:num, n} | rest], count, acc) do
    take_numbers(rest, count - 1, [n | acc])
  end

  defp take_numbers(_, _, _), do: :error

  defp fmt(n) when is_float(n) do
    # Avoid -0.0
    n = if n == 0.0, do: 0.0, else: n

    if n == trunc(n) do
      Integer.to_string(trunc(n))
    else
      :erlang.float_to_binary(n, [{:decimals, 6}, :compact])
    end
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
end
