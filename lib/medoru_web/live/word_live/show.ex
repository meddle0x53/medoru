defmodule MedoruWeb.WordLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    word = Content.get_word_with_kanji!(id)

    {:noreply,
     socket
     |> assign(:word, word)
     |> assign(:page_title, "#{word.text} - #{word.meaning}")}
  end
end
