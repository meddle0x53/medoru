defmodule MedoruWeb.LessonLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    locale = socket.assigns.locale
    lesson = Content.get_lesson_with_words!(id)

    # Get localized content
    localized_title = Content.get_localized_lesson_title(lesson, locale)
    localized_description = Content.get_localized_lesson_description(lesson, locale)

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
     |> assign(:localized_title, localized_title)
     |> assign(:localized_description, localized_description)
     |> assign(:lesson_progress, lesson_progress)
     |> assign(:learned_count, learned_count)
     |> assign(:progress_percentage, progress_percentage)
     |> assign(:page_title, localized_title)}
  end

  # Helper for shared templates
  def page_link_params(assigns, page) do
    assigns = Map.new(assigns)

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: page
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Helper for template: get localized lesson title
  def localized_lesson_title(lesson, locale) do
    Content.get_localized_lesson_title(lesson, locale)
  end

  # Helper for template: get localized lesson description
  def localized_lesson_description(lesson, locale) do
    Content.get_localized_lesson_description(lesson, locale)
  end
end
