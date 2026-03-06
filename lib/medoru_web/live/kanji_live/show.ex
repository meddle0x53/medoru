defmodule MedoruWeb.KanjiLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    kanji = Content.get_kanji_with_readings!(id)

    on_readings = Enum.filter(kanji.kanji_readings, &(&1.reading_type == :on))
    kun_readings = Enum.filter(kanji.kanji_readings, &(&1.reading_type == :kun))

    {:noreply,
     socket
     |> assign(:kanji, kanji)
     |> assign(:on_readings, on_readings)
     |> assign(:kun_readings, kun_readings)
     |> assign(:page_title, "#{kanji.character} - Kanji Details")}
  end
end
