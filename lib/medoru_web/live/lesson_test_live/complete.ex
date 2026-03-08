defmodule MedoruWeb.LessonTestLive.Complete do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Tests

  @impl true
  def mount(%{"lesson_id" => lesson_id}, _session, socket) do
    lesson = Content.get_lesson!(lesson_id)
    user = socket.assigns.current_scope.current_user

    # Get test with steps and latest session
    test =
      Tests.get_test!(lesson.test_id)
      |> Medoru.Repo.preload(:test_steps)

    # Get most recent completed session
    session =
      Tests.list_test_sessions(user.id, test_id: test.id, status: :completed, limit: 1)
      |> List.first()

    socket =
      socket
      |> assign(:lesson, lesson)
      |> assign(:test, test)
      |> assign(:session, session)
      |> assign(:page_title, "Test Complete - #{lesson.title}")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-12">
        <%!-- Success Card --%>
        <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-8 text-center">
          <%!-- Celebration Icon --%>
          <div class="w-24 h-24 bg-success/10 rounded-full flex items-center justify-center mx-auto mb-6">
            <.icon name="hero-trophy" class="w-12 h-12 text-success" />
          </div>

          <h1 class="text-3xl font-bold text-base-content mb-2">Lesson Complete!</h1>
          <p class="text-secondary text-lg mb-8">
            Great job completing "{@lesson.title}"
          </p>

          <%!-- Stats Grid --%>
          <%= if @session do %>
            <div class="grid grid-cols-3 gap-4 mb-8">
              <div class="bg-base-50 rounded-xl p-4">
                <div class="text-3xl font-bold text-primary mb-1">
                  {@session.percentage}%
                </div>
                <div class="text-sm text-secondary">Score</div>
              </div>

              <div class="bg-base-50 rounded-xl p-4">
                <div class="text-3xl font-bold text-primary mb-1">
                  {format_time(@session.time_spent_seconds)}
                </div>
                <div class="text-sm text-secondary">Time</div>
              </div>

              <div class="bg-base-50 rounded-xl p-4">
                <div class="text-3xl font-bold text-primary mb-1">
                  {@session.score}/{@session.total_possible}
                </div>
                <div class="text-sm text-secondary">Correct</div>
              </div>
            </div>

            <%!-- Retry Info --%>
            <%= if @session.metadata["wrong_answer_count"] && @session.metadata["wrong_answer_count"] > 0 do %>
              <div class="bg-info/10 text-info rounded-xl p-4 mb-8">
                <div class="flex items-center gap-3 justify-center">
                  <.icon name="hero-arrow-path" class="w-5 h-5" />
                  <span>
                    You had {@session.metadata["wrong_answer_count"]} retry {if @session.metadata[
                                                                                  "wrong_answer_count"
                                                                                ] == 1,
                                                                                do: "attempt",
                                                                                else: "attempts"} - keep practicing to improve!
                  </span>
                </div>
              </div>
            <% end %>
          <% end %>

          <%!-- Actions --%>
          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <.link
              navigate={~p"/lessons/#{@lesson.id}"}
              class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors"
            >
              <.icon name="hero-book-open" class="w-5 h-5" /> Review Lesson
            </.link>

            <.link
              navigate={~p"/lessons"}
              class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-base-200 text-base-content rounded-xl font-medium hover:bg-base-300 transition-colors"
            >
              <.icon name="hero-list-bullet" class="w-5 h-5" /> All Lessons
            </.link>

            <.link
              navigate={~p"/dashboard"}
              class="inline-flex items-center justify-center gap-2 px-6 py-3 border border-base-300 text-base-content rounded-xl font-medium hover:bg-base-50 transition-colors"
            >
              <.icon name="hero-home" class="w-5 h-5" /> Dashboard
            </.link>
          </div>
        </div>

        <%!-- Words Learned --%>
        <%= if @test.test_steps != [] do %>
          <div class="mt-8 bg-base-100 rounded-2xl shadow-sm border border-base-200 p-6">
            <h2 class="text-lg font-semibold text-base-content mb-4">Words Tested</h2>
            <div class="flex flex-wrap gap-2">
              <%= for word <- get_unique_words(@test.test_steps) do %>
                <span class="px-3 py-1.5 bg-base-100 border border-base-200 rounded-lg text-sm font-medium text-base-content">
                  {word}
                </span>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_time(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    remaining = rem(seconds, 60)
    "#{minutes}m #{remaining}s"
  end

  defp get_unique_words(steps) do
    steps
    |> Enum.map(& &1.correct_answer)
    |> Enum.uniq()
    |> Enum.take(20)
  end
end
