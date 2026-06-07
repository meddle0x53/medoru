defmodule Medoru.Content.KanjiFix do
  @moduledoc """
  One-off fix for kanji with missing or malformed data.
  Run `Medoru.Content.KanjiFix.apply()` in a remote console.
  """

  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiReading}
  import Ecto.Query

  def apply do
    fix_kanji("可",
      strokes: [
        %{path: "M13.88,21.98C18,22.75,21.74,22.34,25.39,22c13.57-1.26,43.04-4.34,58.11-5.52c3.93-0.31,7.74-0.5,11.63,0.33", order: 1, type: "horizontal", direction: "left-to-right"},
        %{path: "M25,42.14c0.87,0.87,1.5,1.99,1.79,3.21c0.74,3.14,1.96,9.62,2.94,15.63c0.28,1.74,0.55,3.45,0.77,5.02", order: 2, type: "vertical", direction: "top-to-bottom"},
        %{path: "M27.38,44.28c7.5-1.77,16.49-3.18,21.87-4.27c3.75-0.76,5.13,1.05,4.31,4.53c-1.01,4.33-1.94,8.21-3.4,14.01", order: 3, type: "corner", direction: "top-left-to-bottom-right"},
        %{path: "M31.2,61.83c5.62-0.7,11.39-1.52,17.83-2.29c1.21-0.14,2.43-0.29,3.69-0.43", order: 4, type: "horizontal", direction: "left-to-right"},
        %{path: "M75.46,20.33c1.04,1.04,2.01,2.67,2.01,4.77c0,14.56-0.01,60.44-0.01,65.4c0,10.62-7.96,1.25-9.46,0", order: 5, type: "hook", direction: "top-to-bottom"}
      ],
      readings: [
        {:on, "カ", "ka"},
        {:on, "コク", "koku"},
        {:kun, "べき", "beki"},
        {:kun, "べし", "beshi"}
      ]
    )

    fix_kanji("籠",
      strokes: [
        %{path: "M31.99,9.75c0.04,0.46,0.1,1.2-0.09,1.87c-1.12,3.94-7.57,12.59-16.4,17.88", order: 1, type: "diagonal", direction: "top-left-to-bottom-right"},
        %{path: "M28.73,20.29C32.72,20.29,45.52,17,50,17", order: 2, type: "horizontal", direction: "left-to-right"},
        %{path: "M36.02,21.83C38.83,23.45,43.3,28.48,44,31", order: 3, type: "dot", direction: "top-left-to-bottom-right"},
        %{path: "M64.97,9.25c0.04,0.42,0.17,1.09-0.08,1.68C63.06,15.32,57.98,21.6,51.25,27", order: 4, type: "diagonal", direction: "top-left-to-bottom-right"},
        %{path: "M61.98,17.68c4.58,0,21.37-3.2,26.52-3.2", order: 5, type: "horizontal", direction: "left-to-right"},
        %{path: "M81.48,17.5c0.03,0.21,0.07,0.55-0.06,0.85c-0.78,1.8-5.27,5.74-11.42,8.15", order: 6, type: "diagonal", direction: "top-right-to-bottom-left"},
        %{path: "M32.38,27.75c0.16,0.47,0.4,1.53,0.4,2.73c0,1.66,0,2.61,0,5.23", order: 7, type: "vertical", direction: "top-to-bottom"},
        %{path: "M18.64,39.38c0.53,0.07,2.37,0.03,2.9,0c3.01-0.16,20.12-1.58,24.67-1.77c0.89-0.04,1.42,0,1.87,0.03", order: 8, type: "horizontal", direction: "left-to-right"},
        %{path: "M21.91,40.64c3.54,4.16,5.15,8.41,5.47,11.15", order: 9, type: "dot", direction: "top-left-to-bottom-right"},
        %{path: "M44.29,37.74c0.55,0.38,0.61,1.43,0.55,1.75c-0.44,2.16-4.99,8.61-6.08,10.27", order: 10, type: "diagonal", direction: "top-right-to-bottom-left"},
        %{path: "M13.49,54.17c0.72,0.41,1.57,0.48,2.3,0.46c8.71-0.26,25.88-2.64,35.13-3.09c1.22-0.06,1.94,0.25,2.55,0.46", order: 11, type: "horizontal", direction: "left-to-right"},
        %{path: "M23.07,61c0.3,0.52,0.5,1.04,0.6,1.55c0.1,0.52,0.14,34.28,0.1,35.45", order: 12, type: "vertical", direction: "top-to-bottom"},
        %{path: "M25.27,62.94c1.6-0.13,16.24-2.24,17.43-2.38c2.13-0.25,2.93,1.63,2.66,2.38c-0.26,0.72-0.4,18.72-0.4,28.89c0,9.02-2.88,5.06-5.8,2.33", order: 13, type: "corner", direction: "top-to-bottom"},
        %{path: "M24.02,71.64c6.05-0.38,15.92-0.74,21.23-0.93", order: 14, type: "horizontal", direction: "left-to-right"},
        %{path: "M24.78,82.15c4.38-0.43,13.98-1.34,19.05-1.85", order: 15, type: "horizontal", direction: "left-to-right"},
        %{path: "M66.35,34.06c4.37-0.32,13.31-1.52,18.25-2.11c1.12-0.13,1.83,0.09,2.4,0.18", order: 16, type: "horizontal", direction: "left-to-right"},
        %{path: "M62.5,27.75c1.25,0.69,1.61,2.35,1.63,3.31c0.04,2.02-0.18,8.32-0.31,11.12c-0.03,0.6,0.25,1.35,2.53,1.06c5.02-0.62,12.34-1.43,17.87-2.25c3.13-0.47,3.22,0.52,2.73,1.56c-0.95,2.01-1.55,5.44-2.52,8.95", order: 17, type: "curve", direction: "right-to-left"},
        %{path: "M64,54.25c4.78-0.32,14.83-1.5,21.5-1.79", order: 18, type: "horizontal", direction: "left-to-right"},
        %{path: "M62.07,51.1c0.76,1.19,1.36,2.61,1.4,4.45c0.2,8.23-0.54,24.77-0.54,30.37c0,13.07,9.07,11.59,18,11.59c14.26,0,15.17-2.79,15.17-9.18", order: 19, type: "curve", direction: "top-to-bottom"},
        %{path: "M64.75,62.88c4.71-0.29,15.35-1.11,20.68-1.65c1.21-0.12,1.97,0.08,2.59,0.17", order: 20, type: "horizontal", direction: "left-to-right"},
        %{path: "M64.91,73.43c4.34-0.38,15.53-1.08,20.45-1.77c1.12-0.16,1.82,0.1,2.39,0.21", order: 21, type: "horizontal", direction: "left-to-right"},
        %{path: "M64.49,84.25c4.33-0.17,16.84-0.64,21.74-0.95c1.12-0.07,1.81,0.05,2.38,0.09", order: 22, type: "horizontal", direction: "left-to-right"}
      ],
      replace_readings: true,
      readings: [
        {:on, "ロウ", "rou"},
        {:kun, "かご", "kago"},
        {:kun, "こも", "komo"}
      ]
    )
  end

  defp fix_kanji(character, opts) do
    kanji = Repo.get_by(Kanji, character: character)

    if kanji do
      # --- Fix stroke data format ---
      stroke_data = kanji.stroke_data || %{}

      new_strokes =
        (opts[:strokes] || [])
        |> Enum.map(fn stroke ->
          %{
            "path" => stroke.path,
            "order" => stroke.order,
            "type" => stroke.type,
            "direction" => stroke.direction
          }
        end)

      new_stroke_data =
        if new_strokes != [] do
          Map.put(stroke_data, "strokes", new_strokes)
        else
          stroke_data
        end

      kanji
      |> Ecto.Changeset.change(stroke_data: new_stroke_data)
      |> Repo.update!()

      IO.puts("Updated stroke data for #{character}")

      # --- Fix readings ---
      if opts[:replace_readings] do
        Repo.delete_all(from r in KanjiReading, where: r.kanji_id == ^kanji.id)
        IO.puts("Cleared old readings for #{character}")
      end

      existing_readings =
        if opts[:replace_readings] do
          []
        else
          Repo.all(from r in KanjiReading, where: r.kanji_id == ^kanji.id)
        end

      for {type, reading, romaji} <- opts[:readings] || [] do
        already_exists =
          Enum.any?(existing_readings, fn r ->
            r.reading_type == type and r.reading == reading
          end)

        unless already_exists do
          %KanjiReading{}
          |> KanjiReading.changeset(%{
            kanji_id: kanji.id,
            reading_type: type,
            reading: reading,
            romaji: romaji
          })
          |> Repo.insert!()

          IO.puts("  Added #{type} reading: #{reading} (#{romaji})")
        end
      end
    else
      IO.puts("Kanji #{character} not found")
    end
  end
end
