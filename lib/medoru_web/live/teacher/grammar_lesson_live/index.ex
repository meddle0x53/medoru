defmodule MedoruWeb.Teacher.GrammarLessonLive.Index do
  @moduledoc """
  Teacher interface for listing grammar lessons.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  @word_type_colors %{
    "verb" => "bg-emerald-500 text-white",
    "noun" => "bg-blue-500 text-white",
    "adjective" => "bg-rose-500 text-white",
    "expression" => "bg-amber-400 text-amber-950",
    "particle" => "bg-orange-500 text-white"
  }

  embed_templates "index/*"

  @impl true
  def render(assigns) do
    ~H"""
    {index(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can access this page."))
       |> push_navigate(to: ~p"/classrooms")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_scope.current_user

    # Get grammar lessons (lesson_subtype: "grammar")
    lessons =
      Content.list_teacher_custom_lessons(user.id)
      |> Enum.filter(&(&1.lesson_subtype == "grammar"))

    {:noreply,
     socket
     |> assign(:page_title, gettext("My Grammar Lessons"))
     |> assign(:lessons, lessons)
     |> assign(:word_type_colors, @word_type_colors)
     |> assign(:word_classes, Content.list_word_classes())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson = Content.get_custom_lesson!(id)

    if lesson.creator_id != user.id do
      {:noreply, put_flash(socket, :error, gettext("You can only delete your own lessons."))}
    else
      case Content.delete_custom_lesson(lesson) do
        {:ok, _} ->
          lessons =
            Content.list_teacher_custom_lessons(user.id)
            |> Enum.filter(&(&1.lesson_subtype == "grammar"))

          {:noreply,
           socket
           |> assign(:lessons, lessons)
           |> put_flash(:info, gettext("Lesson deleted successfully."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete lesson."))}
      end
    end
  end
end
