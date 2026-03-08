defmodule Medoru.Release.Seeds.KanjiVG do
  @moduledoc """
  Seeds KanjiVG stroke data for kanji characters.

  KanjiVG is copyright © Ulrich Apel and released under the
  Creative Commons Attribution-Share Alike 3.0 license.
  See: https://kanjivg.tagaini.net/
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji

  @stroke_data_file Path.join([:code.priv_dir(:medoru), "repo", "seeds", "kanjivg_strokes.json"])

  @doc """
  Seeds KanjiVG stroke data for kanji that exist in the database.
  """
  def seed do
    stroke_data = load_stroke_data()

    if stroke_data == %{} do
      IO.puts("No KanjiVG stroke data found, skipping...")
      :ok
    else
      seeded_count =
        stroke_data
        |> Enum.reduce(0, fn {character, data}, count ->
          case Repo.get_by(Kanji, character: character) do
            nil ->
              IO.puts("  Kanji '#{character}' not found in database, skipping")
              count

            kanji ->
              if has_valid_stroke_data?(kanji.stroke_data) do
                IO.puts("  • '#{character}' already has stroke data, skipping")
                count
              else
                kanji
                |> Ecto.Changeset.change(stroke_data: data)
                |> Repo.update!()

                stroke_count = length(data["strokes"])
                IO.puts("  ✓ Added KanjiVG data for '#{character}' (#{stroke_count} strokes)")
                count + 1
              end
          end
        end)

      IO.puts("\nKanjiVG stroke data seeding complete! Seeded #{seeded_count} kanji.")
      IO.puts("Attribution: KanjiVG © Ulrich Apel (CC BY-SA 3.0)")
      :ok
    end
  end

  @doc """
  Returns the attribution text for KanjiVG.
  """
  def attribution do
    "Kanji stroke diagrams are based on data from KanjiVG (http://kanjivg.tagaini.net), " <>
      "copyright © Ulrich Apel, licensed under CC BY-SA 3.0."
  end

  defp load_stroke_data do
    case File.read(@stroke_data_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"strokes" => strokes}} -> strokes
          _ -> %{}
        end

      {:error, reason} ->
        IO.puts("Warning: Could not read KanjiVG stroke data: #{inspect(reason)}")
        %{}
    end
  end

  defp has_valid_stroke_data?(nil), do: false
  defp has_valid_stroke_data?(%{}), do: false

  defp has_valid_stroke_data?(data) when is_map(data) do
    strokes = data["strokes"] || data[:strokes]
    is_list(strokes) and length(strokes) > 0
  end

  defp has_valid_stroke_data?(_), do: false
end
