defmodule MedoruWeb.ClassroomLive.CustomLessonComplete do
  @moduledoc """
  LiveView for showing completion screen after finishing a custom lesson.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify membership
    case Classrooms.get_user_membership(classroom_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You are not a member of this classroom.")
         |> push_navigate(to: ~p"/classrooms")}

      _membership ->
        load_completion(socket, classroom_id, lesson_id, user)
    end
  end

  defp load_completion(socket, classroom_id, lesson_id, user) do
    classroom = Classrooms.get_classroom!(classroom_id)
    lesson = Content.get_custom_lesson_with_words!(lesson_id)

    # Get the completed progress
    progress = Classrooms.get_custom_lesson_progress(classroom_id, user.id, lesson_id)

    # Calculate points
    word_count = length(lesson.custom_lesson_words)
    points_earned = progress && progress.points_earned || word_count * 10 + 20

    {:ok,
     socket
     |> assign(:classroom, classroom)
     |> assign(:lesson, lesson)
     |> assign(:word_count, word_count)
     |> assign(:points_earned, points_earned)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Lesson Complete!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-12">
        <div class="card bg-base-100 border border-base-300 shadow-lg">
          <div class="card-body text-center py-12">
            <%!-- Success Icon --%>
            <div class="w-24 h-24 mx-auto bg-success/10 rounded-full flex items-center justify-center mb-6">
              <.icon name="hero-check-circle" class="w-16 h-16 text-success" />
            </div>

            <%!-- Title --%>
            <h1 class="text-3xl font-bold text-base-content mb-2">Lesson Complete!</h1>
            <p class="text-xl text-secondary mb-6">{@lesson.title}</p>

            <%!-- Stats --%>
            <div class="flex justify-center gap-8 mb-8">
              <div class="text-center">
                <div class="text-3xl font-bold text-primary">{@word_count}</div>
                <div class="text-sm text-secondary">Words Learned</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold text-primary">+{@points_earned}</div>
                <div class="text-sm text-secondary">Points Earned</div>
              </div>
            </div>

            <%!-- Progress Message --%>
            <div class="alert alert-success mb-8">
              <.icon name="hero-trophy" class="w-5 h-5" />
              <span>Great job! Keep up the good work!</span>
            </div>

            <%!-- Actions --%>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <.link
                navigate={~p"/classrooms/#{@classroom.id}?tab=lessons"}
                class="btn btn-primary"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" />
                Back to Lessons
              </.link>
              <.link
                navigate={~p"/classrooms/#{@classroom.id}/rankings"}
                class="btn btn-ghost"
              >
                <.icon name="hero-chart-bar" class="w-5 h-5 mr-2" />
                View Rankings
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
