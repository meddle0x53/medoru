defmodule MedoruWeb.KanjiPreviewController do
  use MedoruWeb, :controller

  import MedoruWeb.NavigationHelpers

  alias Medoru.Content

  def show(conn, %{"character" => character}) do
    case Content.get_kanji_by_character(character) do
      nil ->
        send_resp(conn, 404, "")

      kanji ->
        readings = kanji.kanji_readings
        on = Enum.find(readings, &(&1.reading_type == :on))
        kun = Enum.find(readings, &(&1.reading_type == :kun))
        locale = conn.assigns[:locale] || "en"
        meanings = Content.get_localized_kanji_meanings(kanji, locale)

        json(conn, %{
          character: kanji.character,
          meanings: Enum.take(meanings, 3),
          stroke_data: kanji.stroke_data,
          on_reading: on && on.reading,
          kun_reading: kun && kun.reading,
          path: kanji_path(kanji)
        })
    end
  end
end
