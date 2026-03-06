defmodule MedoruWeb.LessonLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    lesson = Content.get_lesson_with_words!(id)

    {:noreply,
     socket
     |> assign(:lesson, lesson)
     |> assign(:page_title, lesson.title)}
  end
end
