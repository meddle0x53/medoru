defmodule Medoru.Content.KanjiBulkFix do
  @moduledoc """
  Self-contained bulk fix for ALL kanji stroke and reading issues.
  No embedded data — analyzes existing paths at runtime and fixes bounds/types/directions.
  Run: Medoru.Content.KanjiBulkFix.apply()
  """

  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiReading}
  import Ecto.Query
  require Logger

  # Small embedded reading fixes for kanji not in kanjidic2
  @reading_fixes %{
    "犰" => [%{type: :on, reading: "キュウ", romaji: "kyuu"}],
    "涮" => [%{type: :on, reading: "セン", romaji: "sen"}],
  }

  def apply do
    fix_all_strokes()
    apply_reading_fixes()
  end

  defp fix_all_strokes do
    Logger.info("Analyzing and fixing all kanji strokes...")

    all = Repo.all(Kanji)

    # 1. Fix string-format strokes
    string_kanji = Enum.filter(all, fn k ->
      strokes = get_in(k.stroke_data, ["strokes"])
      is_list(strokes) and length(strokes) > 0 and is_binary(hd(strokes))
    end)

    fixed_string = Enum.reduce(string_kanji, 0, fn kanji, count ->
      new_data = fix_stroke_data(kanji.stroke_data)
      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()
      count + 1
    end)

    # 2. Fix unknown type/direction strokes
    unknown_kanji = Enum.filter(all, fn k ->
      strokes = get_in(k.stroke_data, ["strokes"])
      is_list(strokes) and length(strokes) > 0 and is_map(hd(strokes)) and
        (has_unknown_type?(strokes) or has_unknown_direction?(strokes))
    end)

    fixed_unknown = Enum.reduce(unknown_kanji, 0, fn kanji, count ->
      new_data = fix_stroke_data(kanji.stroke_data)
      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()
      count + 1
    end)

    # 3. Add strokes to kanji with no stroke data (if we have them in other sources)
    no_stroke_kanji = Enum.filter(all, fn k ->
      is_nil(k.stroke_data) or k.stroke_data == %{} or
        is_nil(k.stroke_data["strokes"]) or k.stroke_data["strokes"] == []
    end)

    added = Enum.reduce(no_stroke_kanji, 0, fn kanji, count ->
      # Try to find stroke data from known sources
      case find_stroke_data(kanji.character) do
        nil -> count
        stroke_data ->
          kanji |> Ecto.Changeset.change(stroke_data: stroke_data) |> Repo.update!()
          count + 1
      end
    end)

    Logger.info("Strokes fixed: #{fixed_string} string→map, #{fixed_unknown} unknown fixed, #{added} added")
  end

  defp has_unknown_type?(strokes) do
    Enum.any?(strokes, fn s -> is_map(s) and s["type"] == "unknown" end)
  end

  defp has_unknown_direction?(strokes) do
    Enum.any?(strokes, fn s ->
      is_map(s) and s["direction"] == "unknown" and not closed_path?(s["path"])
    end)
  end

  defp closed_path?(path) when is_binary(path) do
    trimmed = String.trim(path)
    String.ends_with?(trimmed, "Z") or String.ends_with?(trimmed, "z")
  end
  defp closed_path?(_), do: false

  defp fix_stroke_data(nil), do: %{}
  defp fix_stroke_data(stroke_data) when stroke_data == %{}, do: stroke_data
  defp fix_stroke_data(stroke_data) do
    strokes = stroke_data["strokes"] || []

    # Determine coordinate system from paths
    coord_system = detect_coordinate_system(strokes)

    bounds = case coord_system do
      :makemeahanzi -> %{"width" => 1024, "height" => 1024, "viewBox" => "0 0 1024 1024"}
      :kanjivg -> %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}
      :unknown -> stroke_data["bounds"] || %{"width" => 1024, "height" => 1024, "viewBox" => "0 0 1024 1024"}
    end

    new_strokes = Enum.map(strokes, fn stroke ->
      path = if is_binary(stroke), do: stroke, else: stroke["path"]
      order = if is_binary(stroke), do: 0, else: stroke["order"] || 0

      stroke_type = infer_type_from_path(path)
      direction = infer_direction_from_path(path)

      %{
        "path" => path,
        "order" => order,
        "type" => stroke_type,
        "direction" => direction
      }
    end)

    # Preserve any extra fields like decomposition, etymology
    stroke_data
    |> Map.put("strokes", new_strokes)
    |> Map.put("bounds", bounds)
  end

  defp detect_coordinate_system(strokes) when is_list(strokes) and length(strokes) > 0 do
    all_nums = Enum.flat_map(strokes, fn stroke ->
      path = if is_binary(stroke), do: stroke, else: stroke["path"] || ""
      Regex.scan(~r/-?\d+\.?\d*/, path)
      |> List.flatten()
      |> Enum.map(fn n ->
        case Float.parse(n) do
          {f, _} -> abs(f)
          :error -> 0.0
        end
      end)
    end)

    max_val = if all_nums == [], do: 0, else: Enum.max(all_nums)
    cond do
      max_val > 200 -> :makemeahanzi
      max_val > 0 -> :kanjivg
      true -> :unknown
    end
  end
  defp detect_coordinate_system(_), do: :unknown

  defp infer_type_from_path(path) do
    nums = Regex.scan(~r/-?\d+\.?\d*/, path)
    |> List.flatten()
    |> Enum.map(fn n ->
      case Float.parse(n) do
        {f, _} -> f
        :error -> 0.0
      end
    end)

    xs = Enum.take_every(nums, 2)
    ys = Enum.drop_every(nums, 2)

    {min_x, max_x} = if xs == [], do: {0, 0}, else: {Enum.min(xs), Enum.max(xs)}
    {min_y, max_y} = if ys == [], do: {0, 0}, else: {Enum.min(ys), Enum.max(ys)}

    width = max_x - min_x
    height = max_y - min_y

    cond do
      width > height * 2 -> "horizontal"
      height > width * 2 -> "vertical"
      width > 0 and height > 0 -> "diagonal"
      true -> "unknown"
    end
  end

  defp infer_direction_from_path(path) do
    path_trim = String.trim(path)

    # For closed paths (outlines), direction is ambiguous
    if String.ends_with?(path_trim, "Z") or String.ends_with?(path_trim, "z") do
      "unknown"
    else
      match = Regex.run(~r/^[Mm]\s*(-?\d+\.?\d*)[\s,]+(-?\d+\.?\d*)/, path)
      if match do
        start_x = parse_number(Enum.at(match, 1))
        start_y = parse_number(Enum.at(match, 2))

        # Find last coordinate pair
        coords = Regex.scan(~r/(-?\d+\.?\d*)[\s,]+(-?\d+\.?\d*)/, path)
        if coords != [] do
          last = List.last(coords)
          end_x = parse_number(Enum.at(last, 1))
          end_y = parse_number(Enum.at(last, 2))

          dx = end_x - start_x
          dy = end_y - start_y
          abs_dx = abs(dx)
          abs_dy = abs(dy)

          cond do
            abs_dx < 1 and abs_dy < 1 -> "unknown"
            abs_dx > abs_dy * 2 -> if dx > 0, do: "left-to-right", else: "right-to-left"
            abs_dy > abs_dx * 2 -> if dy > 0, do: "top-to-bottom", else: "bottom-to-top"
            dx > 0 and dy > 0 -> "top-left-to-bottom-right"
            dx < 0 and dy > 0 -> "top-right-to-bottom-left"
            dx > 0 and dy < 0 -> "bottom-left-to-top-right"
            true -> "bottom-right-to-top-left"
          end
        else
          "unknown"
        end
      else
        "unknown"
      end
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error ->
        case Integer.parse(str) do
          {i, _} -> i * 1.0
          :error -> 0.0
        end
    end
  end

  # Try to find stroke data from various sources
  defp find_stroke_data(character) do
    # Try KanjiVG SVG files
    hex = Integer.to_string(:binary.first(character), 16) |> String.pad_leading(5, "0")
    svg_path = Path.join([:code.priv_dir(:medoru), "..", "..", "raw", "kanjivg", "kanji", "#{hex}.svg"])
    |> Path.expand()

    if File.exists?(svg_path) do
      case parse_kanjivg_svg(svg_path) do
        nil -> nil
        strokes -> %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}}
      end
    else
      nil
    end
  end

  defp parse_kanjivg_svg(svg_path) do
    case File.read(svg_path) do
      {:ok, content} ->
        # Simple regex-based SVG path extraction
        paths = Regex.scan(~r/<path[^>]*d="([^"]*)"[^>]*>/, content)
        |> Enum.map(fn [_, d] -> d end)
        |> Enum.with_index(1)
        |> Enum.map(fn {d, idx} ->
          %{
            "path" => d,
            "order" => idx,
            "type" => infer_type_from_path(d),
            "direction" => infer_direction_from_path(d)
          }
        end)
        if paths == [], do: nil, else: paths
      {:error, _} -> nil
    end
  end

  defp apply_reading_fixes do
    Logger.info("Applying reading fixes...")

    kanji_without_readings =
      from(k in Kanji,
        left_join: r in assoc(k, :kanji_readings),
        where: not is_nil(k.stroke_data) and k.stroke_data != ^%{},
        group_by: k.id,
        having: count(r.id) == 0,
        select: k
      )
      |> Repo.all()

    inserted =
      Enum.reduce(kanji_without_readings, 0, fn kanji, count ->
        case Map.fetch(@reading_fixes, kanji.character) do
          {:ok, readings} when is_list(readings) and readings != [] ->
            n = Enum.reduce(readings, 0, fn r, inner ->
              attrs = %{kanji_id: kanji.id, reading_type: r.type, reading: r.reading, romaji: r.romaji}
              case %KanjiReading{} |> KanjiReading.changeset(attrs) |> Repo.insert() do
                {:ok, _} -> inner + 1
                {:error, _} -> inner
              end
            end)
            count + n

          _ -> count
        end
      end)

    Logger.info("Inserted #{inserted} readings")
  end
end
