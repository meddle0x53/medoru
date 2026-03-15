defmodule MedoruWeb.ClassroomLive.Show do
  @moduledoc """
  LiveView for students to view a classroom they're a member of.
  Shows classroom info, rankings, and available lessons/tests.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    case Classrooms.get_user_membership(id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You are not a member of this classroom.")
         |> push_navigate(to: ~p"/classrooms")}

      membership ->
        if membership.status != :approved do
          {:ok,
           socket
           |> put_flash(:error, "Your membership is pending approval.")
           |> push_navigate(to: ~p"/classrooms")}
        else
          classroom = Classrooms.get_classroom!(id)
          members = Classrooms.list_classroom_members(id)
          published_tests = Classrooms.list_classroom_tests(id, status: :active)
          user_attempts = Classrooms.list_user_test_attempts(id, user.id)
          custom_lessons = Medoru.Content.list_classroom_custom_lessons(id)
          lesson_progress = Classrooms.list_user_custom_lesson_progress(id, user.id)

          {:ok,
           socket
           |> assign(:page_title, classroom.name)
           |> assign(:classroom, classroom)
           |> assign(:membership, membership)
           |> assign(:members, members)
           |> assign(:published_tests, published_tests)
           |> assign(:user_attempts, user_attempts)
           |> assign(:custom_lessons, custom_lessons)
           |> assign(:lesson_progress, lesson_progress)
           |> assign(:active_tab, "overview")}
        end
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> push_patch(to: ~p"/classrooms/#{socket.assigns.classroom.id}?tab=#{tab}")}
  end

  @impl true
  def handle_event("leave_classroom", _, socket) do
    membership = socket.assigns.membership

    case Classrooms.leave_classroom(membership) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the classroom.")
         |> push_navigate(to: ~p"/classrooms")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave classroom.")}
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
            navigate={~p"/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to My Classrooms
          </.link>

          <div class="flex items-start justify-between">
            <div>
              <h1 class="text-3xl font-bold text-base-content">{@classroom.name}</h1>
              <p class="text-secondary max-w-2xl mt-2">
                {@classroom.description || "No description"}
              </p>
            </div>

            <button
              phx-click="leave_classroom"
              data-confirm="Are you sure you want to leave this classroom?"
              class="btn btn-error btn-outline btn-sm"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 mr-1" /> Leave
            </button>
          </div>
        </div>

        <%!-- My Stats Card --%>
        <div class="card bg-gradient-to-br from-primary/10 to-secondary/10 border border-primary/20 mb-8">
          <div class="card-body">
            <div class="flex items-center gap-4">
              <div class="w-16 h-16 bg-primary/20 rounded-full flex items-center justify-center">
                <.icon name="hero-trophy" class="w-8 h-8 text-primary" />
              </div>
              <div>
                <p class="text-sm text-secondary">My Points</p>
                <p class="text-3xl font-bold text-base-content">{@membership.points}</p>
              </div>
              <div class="ml-auto text-right">
                <p class="text-sm text-secondary">Rank</p>
                <p class="text-2xl font-bold text-base-content">
                  #{get_rank(@members, @current_scope.current_user.id)}
                </p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Tabs --%>
        <div class="border-b border-base-300 mb-6">
          <div class="flex gap-1">
            <.tab_button active={@active_tab == "overview"} tab="overview" label="Overview" />
            <.tab_button active={@active_tab == "rankings"} tab="rankings" label="Rankings" />
            <.tab_button active={@active_tab == "lessons"} tab="lessons" label="Lessons" />
            <.tab_button active={@active_tab == "tests"} tab="tests" label="Tests" />
          </div>
        </div>

        <%!-- Tab Content --%>
        <div class="min-h-[400px]">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab
                classroom={@classroom}
                members={@members}
                current_user={@current_scope.current_user}
              />
            <% "rankings" -> %>
              <.rankings_tab members={@members} current_user={@current_scope.current_user} />
            <% "lessons" -> %>
              <.lessons_tab
                classroom={@classroom}
                custom_lessons={@custom_lessons}
                lesson_progress={@lesson_progress}
                current_user={@current_scope.current_user}
              />
            <% "tests" -> %>
              <.tests_tab
                classroom={@classroom}
                published_tests={@published_tests}
                user_attempts={@user_attempts}
                current_user={@current_scope.current_user}
              />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Tab Components
  # ============================================================================

  defp overview_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Classroom Info --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">About this Classroom</h3>
          <div class="space-y-3">
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Teacher</span>
              <span class="font-medium text-base-content">
                {display_name(@classroom.teacher, @current_user.id, @current_user.type == "admin")}
              </span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Members</span>
              <span class="font-medium text-base-content">{length(@members)} students</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-base-200">
              <span class="text-secondary">Created</span>
              <span class="text-base-content">
                {Calendar.strftime(@classroom.inserted_at, "%B %d, %Y")}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Top Students --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">Top Students</h3>
          <%= if @members == [] do %>
            <p class="text-secondary">No members yet.</p>
          <% else %>
            <div class="space-y-2">
              <%= for {member, index} <- Enum.take(@members, 5) |> Enum.with_index(1) do %>
                <div class={[
                  "flex items-center justify-between p-3 rounded-xl",
                  member.user_id == @current_user.id && "bg-primary/10"
                ]}>
                  <div class="flex items-center gap-3">
                    <span class={[
                      "w-8 h-8 rounded-lg flex items-center justify-center font-bold text-sm",
                      index == 1 && "bg-yellow-100 text-yellow-700",
                      index == 2 && "bg-gray-200 text-gray-700",
                      index == 3 && "bg-orange-100 text-orange-700",
                      index > 3 && "bg-base-200 text-secondary"
                    ]}>
                      {index}
                    </span>
                    <span class={
                      member.user_id == @current_user.id && "font-medium text-base-content"
                    }>
                      {display_name(member.user, @current_user.id, @current_user.type == "admin")}
                      <%= if member.user_id == @current_user.id do %>
                        <span class="badge badge-primary badge-sm ml-2">You</span>
                      <% end %>
                    </span>
                  </div>
                  <span class="font-semibold text-base-content">{member.points} pts</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp rankings_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm">
      <div class="card-body">
        <div class="flex justify-between items-center mb-4">
          <h3 class="card-title text-base-content">Classroom Rankings</h3>
          <.link
            navigate={~p"/classrooms/#{@current_user.id}/rankings"}
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> Full Rankings
          </.link>
        </div>
        <%= if @members == [] do %>
          <p class="text-secondary">No members yet.</p>
        <% else %>
          <div class="space-y-2">
            <%= for {member, index} <- Enum.with_index(@members, 1) do %>
              <div class={[
                "flex items-center justify-between p-4 rounded-xl",
                member.user_id == @current_user.id && "bg-primary/10 border border-primary/30"
              ]}>
                <div class="flex items-center gap-4">
                  <span class={[
                    "w-10 h-10 rounded-xl flex items-center justify-center font-bold",
                    index == 1 && "bg-yellow-100 text-yellow-700",
                    index == 2 && "bg-gray-200 text-gray-700",
                    index == 3 && "bg-orange-100 text-orange-700",
                    index > 3 && "bg-base-200 text-secondary"
                  ]}>
                    {index}
                  </span>
                  <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
                    <.icon name="hero-user" class="w-5 h-5 text-secondary" />
                  </div>
                  <div>
                    <p class={member.user_id == @current_user.id && "font-medium text-base-content"}>
                      {display_name(member.user, @current_user.id, @current_user.type == "admin")}
                      <%= if member.user_id == @current_user.id do %>
                        <span class="badge badge-primary badge-sm ml-2">You</span>
                      <% end %>
                    </p>
                    <p class="text-sm text-secondary">
                      Joined {Calendar.strftime(member.joined_at || member.inserted_at, "%b %d, %Y")}
                    </p>
                  </div>
                </div>
                <span class="font-bold text-lg text-base-content">{member.points} pts</span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :custom_lessons, :list, required: true
  attr :lesson_progress, :list, required: true
  attr :current_user, :map, required: true

  defp lessons_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if @custom_lessons == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
          <.icon name="hero-book-open" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h3 class="text-xl font-semibold text-base-content mb-2">No Lessons Available</h3>
          <p class="text-secondary max-w-md mx-auto">
            Your teacher hasn't published any lessons to this classroom yet. Check back later!
          </p>
        </div>
      <% else %>
        <%= for classroom_lesson <- @custom_lessons do %>
          <% lesson = classroom_lesson.custom_lesson %>
          <% progress = get_lesson_progress(@lesson_progress, lesson.id) %>
          <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="card-title text-lg text-base-content mb-1">
                    {lesson.title}
                  </h3>
                  <p class="text-secondary text-sm mb-3">
                    {lesson.description || "No description"}
                  </p>

                  <div class="flex flex-wrap gap-3 text-sm">
                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-bookmark" class="w-3 h-3 mr-1" />
                      {lesson.word_count} words
                    </span>

                    <%= if lesson.difficulty do %>
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-signal" class="w-3 h-3 mr-1" />
                        N{lesson.difficulty}
                      </span>
                    <% end %>

                    <%= case progress && progress.status do %>
                      <% "completed" -> %>
                        <span class="badge badge-success badge-sm">
                          <.icon name="hero-check" class="w-3 h-3 mr-1" />
                          Completed
                        </span>
                      <% "in_progress" -> %>
                        <span class="badge badge-warning badge-sm">
                          <.icon name="hero-play" class="w-3 h-3 mr-1" />
                          In Progress
                        </span>
                      <% _ -> %>
                        <span class="badge badge-ghost badge-sm">
                          Not Started
                        </span>
                    <% end %>
                  </div>
                </div>

                <div class="ml-4">
                  <%= case progress && progress.status do %>
                    <% "completed" -> %>
                      <span class="badge badge-success">
                        +{progress.points_earned} pts
                      </span>
                    <% _ -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{lesson.id}"}
                        class="btn btn-primary"
                      >
                        <%= if progress && progress.status == "in_progress" do %>
                          <.icon name="hero-play" class="w-4 h-4 mr-1" /> Continue
                        <% else %>
                          <.icon name="hero-book-open" class="w-4 h-4 mr-1" /> Start
                        <% end %>
                      </.link>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp get_lesson_progress(progress_list, lesson_id) do
    Enum.find(progress_list, fn p -> p.custom_lesson_id == lesson_id end)
  end

  attr :classroom, :map, required: true
  attr :published_tests, :list, required: true
  attr :user_attempts, :list, required: true
  attr :current_user, :map, required: true

  defp tests_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if @published_tests == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
          <.icon name="hero-clipboard-document-list" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h3 class="text-xl font-semibold text-base-content mb-2">No Tests Available</h3>
          <p class="text-secondary max-w-md mx-auto">
            Your teacher hasn't published any tests to this classroom yet. Check back later!
          </p>
        </div>
      <% else %>
        <%= for classroom_test <- @published_tests do %>
          <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="card-title text-lg text-base-content mb-1">
                    {classroom_test.test.title}
                  </h3>
                  <p class="text-secondary text-sm mb-3">
                    {classroom_test.test.description || "No description"}
                  </p>

                  <div class="flex flex-wrap gap-3 text-sm">
                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-clock" class="w-3 h-3 mr-1" />
                      <%= if classroom_test.test.time_limit_seconds do %>
                        {format_duration(classroom_test.test.time_limit_seconds)}
                      <% else %>
                        No time limit
                      <% end %>
                    </span>

                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-star" class="w-3 h-3 mr-1" />
                      {classroom_test.test.total_points} points
                    </span>

                    <%= if classroom_test.max_attempts do %>
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-arrow-path" class="w-3 h-3 mr-1" />
                        {classroom_test.max_attempts} attempt{classroom_test.max_attempts != 1 && "s"}
                      </span>
                    <% end %>

                    <%= if classroom_test.due_date do %>
                      <% is_overdue =
                        DateTime.compare(classroom_test.due_date, DateTime.utc_now()) == :lt %>
                      <span class={[
                        "badge badge-sm",
                        is_overdue && "badge-error",
                        !is_overdue && "badge-warning"
                      ]}>
                        <.icon name="hero-calendar" class="w-3 h-3 mr-1" />
                        <%= if is_overdue do %>
                          Overdue
                        <% else %>
                          Due {Calendar.strftime(classroom_test.due_date, "%b %d")}
                        <% end %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <div class="ml-4">
                  <% attempt = get_attempt_for_test(@user_attempts, classroom_test.test_id) %>
                  <%= case get_test_status(@classroom.id, @current_user.id, classroom_test.test_id, attempt) do %>
                    <% :not_started -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-primary"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> Start Test
                      </.link>
                    <% :in_progress -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-warning"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> Continue
                      </.link>
                    <% :completed -> %>
                      <span class="badge badge-success">
                        Completed {attempt.score}/{attempt.max_score}
                      </span>
                    <% :timed_out -> %>
                      <span class="badge badge-error">Timed Out</span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp can_take_test?(classroom_id, user_id, test_id) do
    Classrooms.can_take_test?(classroom_id, user_id, test_id)
  end

  defp get_attempt_for_test(attempts, test_id) do
    Enum.find(attempts, &(&1.test_id == test_id))
  end

  defp get_test_status(classroom_id, user_id, test_id, nil) do
    if can_take_test?(classroom_id, user_id, test_id) do
      :not_started
    else
      :not_started
    end
  end

  defp get_test_status(_classroom_id, _user_id, _test_id, attempt) do
    case attempt.status do
      "in_progress" -> :in_progress
      "completed" -> :completed
      "timed_out" -> :timed_out
      _ -> :completed
    end
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_duration(seconds) when seconds < 3600 do
    "#{div(seconds, 60)}m"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    mins = rem(seconds, 3600) |> div(60)
    "#{hours}h #{mins}m"
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :label, :string, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={[
        "px-4 py-3 text-sm font-medium border-b-2 transition-colors",
        @active && "border-primary text-primary",
        !@active && "border-transparent text-secondary hover:text-base-content hover:border-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp get_rank(members, user_id) do
    members
    |> Enum.with_index(1)
    |> Enum.find(fn {member, _index} -> member.user_id == user_id end)
    |> case do
      nil -> "-"
      {_member, index} -> index
    end
  end
end
