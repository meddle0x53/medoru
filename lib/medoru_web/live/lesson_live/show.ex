defmodule MedoruWeb.LessonLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    lesson = Content.get_lesson_with_words!(id)

    # Fetch lesson progress if user is authenticated
    lesson_progress =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Learning.get_lesson_progress(socket.assigns.current_scope.current_user.id, id)
      else
        nil
      end

    # Count learned words in this lesson
    learned_count =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Learning.count_learned_words_in_lesson(
          socket.assigns.current_scope.current_user.id,
          id
        )
      else
        0
      end

    # Calculate progress percentage for display
    progress_percentage =
      cond do
        lesson_progress && lesson_progress.status == :completed -> 100
        lesson_progress -> lesson_progress.progress_percentage
        true -> 0
      end

    {:noreply,
     socket
     |> assign(:lesson, lesson)
     |> assign(:lesson_progress, lesson_progress)
     |> assign(:learned_count, learned_count)
     |> assign(:progress_percentage, progress_percentage)
     |> assign(:page_title, lesson.title)}
  end
end
