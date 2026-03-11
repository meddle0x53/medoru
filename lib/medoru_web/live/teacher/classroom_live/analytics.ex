defmodule MedoruWeb.Teacher.ClassroomLive.Analytics do
  @moduledoc """
  LiveView for teachers to view classroom analytics.
  Shows:
  - Overall statistics
  - Test performance
  - Lesson progress
  - Student activity over time
  - Top performers
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(id)

    # Verify teacher owns this classroom
    if classroom.teacher_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to view this analytics.")
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      analytics = Classrooms.get_classroom_analytics(id)

      {:ok,
       socket
       |> assign(:page_title, "Analytics - #{classroom.name}")
       |> assign(:classroom, classroom)
       |> assign(:analytics, analytics)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Classroom
          </.link>

          <h1 class="text-3xl font-bold text-base-content">Classroom Analytics</h1>
          <p class="text-secondary mt-1">{@classroom.name} - Performance insights</p>
        </div>

        <%!-- Stats Overview --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <.stat_card
            icon="hero-users"
            label="Total Students"
            value={@analytics.stats.total_members}
            color="blue"
          />
          <.stat_card
            icon="hero-clipboard-document-check"
            label="Test Attempts"
            value={@analytics.test_stats.total_attempts}
            color="green"
          />
          <.stat_card
            icon="hero-book-open"
            label="Lessons Completed"
            value={@analytics.lesson_stats.total_completed}
            color="purple"
          />
          <.stat_card
            icon="hero-star"
            label="Avg Test Score"
            value={@analytics.test_stats.average_score}
            color="yellow"
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <%!-- Test Performance --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content flex items-center gap-2">
                <.icon name="hero-chart-bar" class="w-5 h-5" /> Test Performance
              </h2>

              <div class="space-y-4 mt-4">
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">Total Attempts</span>
                  <span class="font-semibold">{@analytics.test_stats.total_attempts}</span>
                </div>
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">Completed on Time</span>
                  <span class="font-semibold text-success">
                    {@analytics.test_stats.completed_on_time}
                  </span>
                </div>
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">Timed Out</span>
                  <span class="font-semibold text-warning">{@analytics.test_stats.timed_out}</span>
                </div>
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">Completion Rate</span>
                  <span class="font-semibold">
                    {format_percentage(@analytics.test_stats.completion_rate)}%
                  </span>
                </div>
                <div class="flex justify-between items-center py-2">
                  <span class="text-secondary">Average Score</span>
                  <span class="font-semibold text-primary">
                    {@analytics.test_stats.average_score}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Lesson Progress --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content flex items-center gap-2">
                <.icon name="hero-book-open" class="w-5 h-5" /> Lesson Progress
              </h2>

              <div class="space-y-4 mt-4">
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">Completed</span>
                  <span class="font-semibold text-success">
                    {@analytics.lesson_stats.total_completed}
                  </span>
                </div>
                <div class="flex justify-between items-center py-2 border-b border-base-200">
                  <span class="text-secondary">In Progress</span>
                  <span class="font-semibold text-info">{@analytics.lesson_stats.in_progress}</span>
                </div>
                <div class="flex justify-between items-center py-2">
                  <span class="text-secondary">Average Points</span>
                  <span class="font-semibold text-primary">
                    {@analytics.lesson_stats.average_points}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Top Performers --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm mt-8">
          <div class="card-body">
            <h2 class="card-title text-base-content flex items-center gap-2 mb-4">
              <.icon name="hero-trophy" class="w-5 h-5" /> Top Performers
            </h2>

            <%= if @analytics.top_performers == [] do %>
              <p class="text-secondary text-center py-8">
                No data yet. Students need to complete tests and lessons.
              </p>
            <% else %>
              <div class="space-y-2">
                <%= for entry <- @analytics.top_performers do %>
                  <div class="flex items-center gap-4 p-4 bg-base-200/50 rounded-xl">
                    <div class="w-10 text-center font-bold text-primary">
                      #{entry.rank}
                    </div>
                    <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
                      <.icon name="hero-user" class="w-5 h-5 text-secondary" />
                    </div>
                    <div class="flex-1">
                      <p class="font-medium text-base-content">{entry.user.name || "Anonymous"}</p>
                    </div>
                    <div class="text-right">
                      <p class="text-xl font-bold text-primary">{entry.points}</p>
                      <p class="text-xs text-secondary">points</p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Recent Activity --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm mt-8">
          <div class="card-body">
            <h2 class="card-title text-base-content flex items-center gap-2 mb-4">
              <.icon name="hero-clock" class="w-5 h-5" /> Recent Activity (Last 30 Days)
            </h2>

            <%= if @analytics.activity == [] do %>
              <p class="text-secondary text-center py-8">No recent activity.</p>
            <% else %>
              <div class="space-y-2 max-h-96 overflow-y-auto">
                <%= for day <- @analytics.activity do %>
                  <div class="flex items-center justify-between p-3 bg-base-200/50 rounded-lg">
                    <div class="flex items-center gap-3">
                      <div class="w-2 h-2 rounded-full bg-primary"></div>
                      <span class="text-sm text-base-content">{format_date(day.date)}</span>
                    </div>
                    <div class="flex gap-4 text-sm">
                      <span class="text-secondary">
                        {day.attempts} attempt{if day.attempts != 1, do: "s"}
                      </span>
                      <span class="text-primary font-medium">
                        +{day.total_points} pts
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Recent Test Attempts --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm mt-8">
          <div class="card-body">
            <h2 class="card-title text-base-content flex items-center gap-2 mb-4">
              <.icon name="hero-clipboard-document-list" class="w-5 h-5" /> Recent Test Attempts
            </h2>

            <%= if @analytics.recent_attempts == [] do %>
              <p class="text-secondary text-center py-8">No test attempts yet.</p>
            <% else %>
              <div class="space-y-2 max-h-96 overflow-y-auto">
                <%= for attempt <- @analytics.recent_attempts do %>
                  <div class={[
                    "flex items-center justify-between p-4 rounded-xl",
                    attempt.status == "timed_out" && "bg-warning/10",
                    attempt.status != "timed_out" && "bg-base-200/50"
                  ]}>
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
                        <.icon name="hero-user" class="w-5 h-5 text-secondary" />
                      </div>
                      <div>
                        <p class="font-medium text-base-content">
                          {attempt.user.name || "Anonymous"}
                        </p>
                        <p class="text-sm text-secondary">
                          {attempt.test.title}
                        </p>
                      </div>
                    </div>
                    <div class="text-right">
                      <%= if attempt.status == "timed_out" do %>
                        <span class="badge badge-warning">Timed Out</span>
                      <% else %>
                        <p class="font-semibold text-primary">{attempt.points_earned} pts</p>
                        <p class="text-xs text-secondary">
                          {attempt.score}/{attempt.max_score}
                        </p>
                      <% end %>
                      <p class="text-xs text-secondary mt-1">
                        {format_relative_time(attempt.completed_at)}
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  defp stat_card(%{color: "blue"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex flex-row items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-blue-100/80 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  defp stat_card(%{color: "green"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex flex-row items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-green-100/80 dark:bg-green-900/30 text-green-600 dark:text-green-400">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  defp stat_card(%{color: "purple"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex flex-row items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-purple-100/80 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  defp stat_card(%{color: "yellow"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex flex-row items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-amber-100/80 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_percentage(decimal) when is_struct(decimal, Decimal) do
    Decimal.round(Decimal.mult(decimal, 100), 1)
  end

  defp format_percentage(float) when is_float(float) do
    Float.round(float * 100, 1)
  end

  defp format_percentage(_), do: 0

  defp format_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%b %d, %Y")
      _ -> date_string
    end
  end

  defp format_relative_time(datetime) do
    MedoruWeb.Components.Helpers.format_relative_time(datetime)
  end
end
