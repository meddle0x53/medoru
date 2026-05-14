defmodule MedoruWeb.Teacher.DashboardLive do
  @moduledoc """
  Teacher dashboard with cards for all teacher-related functionality.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts.User
  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests

  embed_templates "dashboard_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {dashboard(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if not User.teacher?(user) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can access this page."))
       |> push_navigate(to: ~p"/")}
    else
      classrooms = Classrooms.list_teacher_classrooms(user.id)
      tests = Tests.list_teacher_tests(user.id)
      lessons = Content.list_teacher_custom_lessons(user.id)
      grammar_lessons = Enum.filter(lessons, &(&1.lesson_subtype == "grammar"))

      {:ok,
       socket
       |> assign(:page_title, gettext("Teacher"))
       |> assign(:classroom_count, length(classrooms))
       |> assign(:test_count, length(tests))
       |> assign(:lesson_count, length(lessons))
       |> assign(:grammar_lesson_count, length(grammar_lessons))}
    end
  end
end
