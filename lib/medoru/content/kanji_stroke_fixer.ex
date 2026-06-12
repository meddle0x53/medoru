defmodule Medoru.Content.KanjiStrokeFixer do
  @moduledoc """
  Imports stroke data from KanjiVG for kanji missing stroke_data.

  Uses `priv/repo/seeds/kanjivg_stroke_fixes.json` which contains
  parsed KanjiVG SVG stroke paths for kanji not covered by makemeahanzi.
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji
  require Logger

  @seed_file "priv/repo/seeds/kanjivg_stroke_fixes.json"

  @doc """
  Apply KanjiVG stroke data to kanji missing stroke_data.
  Returns {:ok, count} on success.
  """
  def apply! do
    seed_file =
      if File.exists?(@seed_file) do
        @seed_file
      else
        Path.join([:code.priv_dir(:medoru), "repo", "seeds", "kanjivg_stroke_fixes.json"])
      end

    case File.read(seed_file) do
      {:ok, contents} ->
        fixes = Jason.decode!(contents)
        apply_fixes(fixes)

      {:error, reason} ->
        Logger.error("Could not read #{seed_file}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp apply_fixes(fixes) when is_map(fixes) do
    changed =
      Enum.reduce(fixes, 0, fn {char, stroke_data}, count ->
        case Repo.get_by(Kanji, character: char) do
          nil ->
            count

          kanji ->
            current = kanji.stroke_data || %{}

            # Only update if stroke_data is empty or missing strokes
            if current == %{} or is_nil(current["strokes"]) or current["strokes"] == [] do
              new_stroke_data =
                current
                |> Map.merge(stroke_data)
                |> Map.put_new("bounds", %{
                  "width" => 109,
                  "height" => 109,
                  "viewBox" => "0 0 109 109"
                })

              kanji
              |> Ecto.Changeset.change(stroke_data: new_stroke_data)
              |> Repo.update!()

              count + 1
            else
              count
            end
        end
      end)

    Logger.info("Applied KanjiVG stroke fixes: #{changed} kanji updated")
    {:ok, changed}
  end
end
