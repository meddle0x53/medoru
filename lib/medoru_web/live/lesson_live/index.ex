defmodule MedoruWeb.LessonLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :difficulty, 5)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    lessons = Content.list_lessons_by_difficulty(difficulty)

    # Fetch lesson progress for all lessons if user is authenticated
    lesson_progress_map =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        user_id = socket.assigns.current_scope.current_user.id
        lesson_ids = Enum.map(lessons, & &1.id)

        Learning.list_lesson_progress(user_id)
        |> Enum.filter(&(&1.lesson_id in lesson_ids))
        |> Map.new(&{&1.lesson_id, &1})
      else
        %{}
      end

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:lessons, lessons)
     |> assign(:lesson_progress_map, lesson_progress_map)
     |> assign(:page_title, "JLPT N#{difficulty} Lessons")}
  end

  defp parse_difficulty(nil), do: 5

  defp parse_difficulty(difficulty) when is_binary(difficulty) do
    case Integer.parse(difficulty) do
      {n, _} when n in 1..5 -> n
      _ -> 5
    end
  end

  defp parse_difficulty(difficulty) when is_integer(difficulty) and difficulty in 1..5,
    do: difficulty

  defp parse_difficulty(_), do: 5
end
