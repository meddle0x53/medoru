defmodule Medoru.Content.KanjiStrokeData do
  @moduledoc """
  Looks up stroke data for a kanji character from local KanjiVG SVG files.

  Returns data in the same shape stored in `kanji.stroke_data`:

      %{
        "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"},
        "strokes" => [
          %{"path" => "M...", "order" => 1, "type" => "...", "direction" => "..."}
        ]
      }
  """

  alias Medoru.Content.KanjiStrokePathFix

  @doc """
  Returns stroke data for `character` from the local KanjiVG dataset, or `nil`
  if no SVG file is found.
  """
  def find(character) when is_binary(character) do
    case kanjivg_path(character) do
      nil ->
        nil

      svg_path ->
        case parse_kanjivg_svg(svg_path) do
          nil ->
            nil

          strokes ->
            %{
              "bounds" => %{
                "width" => 109,
                "height" => 109,
                "viewBox" => "0 0 109 109"
              },
              "strokes" => strokes
            }
        end
    end
  end

  def find(_), do: nil

  defp kanjivg_path(character) when is_binary(character) and byte_size(character) > 0 do
    hex =
      character
      |> String.to_charlist()
      |> hd()
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(5, "0")

    raw_dir = Application.get_env(:medoru, :raw_data_dir, "raw")
    path = Path.join([raw_dir, "kanjivg", "kanji", "#{hex}.svg"])

    if File.exists?(path), do: path, else: nil
  end

  defp kanjivg_path(_), do: nil

  defp parse_kanjivg_svg(svg_path) do
    case File.read(svg_path) do
      {:ok, content} ->
        paths =
          Regex.scan(~r/<path[^>]*d="([^"]*)"[^>]*>/, content)
          |> Enum.map(fn [_, d] -> d end)
          |> Enum.with_index(1)
          |> Enum.map(fn {d, idx} ->
            normalized = KanjiStrokePathFix.normalize_path(d)

            %{
              "path" => normalized,
              "order" => idx,
              "type" => infer_type_from_path(normalized),
              "direction" => infer_direction_from_path(normalized)
            }
          end)

        if paths == [], do: nil, else: paths

      {:error, _} ->
        nil
    end
  end

  # The following inference helpers are duplicated from KanjiBulkFix because that
  # module is intentionally self-contained. Keeping them here lets us produce the
  # same canonical stroke metadata shape without running the full bulk fix.

  defp infer_type_from_path(path) when is_binary(path) do
    cond do
      String.match?(path, ~r/[Cc]/) -> "curve"
      String.match?(path, ~r/[LlHhVv]/) -> "straight"
      String.match?(path, ~r/M[^Z]*Z/i) -> "closed"
      true -> "unknown"
    end
  end

  defp infer_type_from_path(_), do: "unknown"

  defp infer_direction_from_path(path) when is_binary(path) do
    coords =
      Regex.scan(~r/(-?\d+\.?\d*)/, path)
      |> Enum.map(fn [_, n] ->
        case Float.parse(n) do
          {f, _} -> f
          :error -> 0.0
        end
      end)

    case coords do
      [] ->
        "unknown"

      [_] ->
        "unknown"

      coords ->
        xs = Enum.take_every(coords, 2)
        ys = Enum.drop_every(coords, 2)

        dx = List.last(xs) - hd(xs)
        dy = List.last(ys) - hd(ys)

        cond do
          abs(dx) > abs(dy) and dx > 0 -> "left-to-right"
          abs(dx) > abs(dy) and dx < 0 -> "right-to-left"
          abs(dy) >= abs(dx) and dy > 0 -> "top-to-bottom"
          abs(dy) >= abs(dx) and dy < 0 -> "bottom-to-top"
          true -> "unknown"
        end
    end
  end

  defp infer_direction_from_path(_), do: "unknown"
end
