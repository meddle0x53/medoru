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
         |> put_flash(:error, gettext("You are not a member of this classroom."))
         |> push_navigate(to: ~p"/classrooms")}

      membership ->
        if membership.status != :approved do
          {:ok,
           socket
           |> put_flash(:error, gettext("Your membership is pending approval."))
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
         |> put_flash(:info, gettext("You have left the classroom."))
         |> push_navigate(to: ~p"/classrooms")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to leave classroom."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-6 sm:mb-8">
          <.link
            navigate={~p"/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-3 sm:mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to My Classrooms")}
          </.link>

          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div class="flex-1 min-w-0">
              <h1 class="text-2xl sm:text-3xl font-bold text-base-content truncate">
                {@classroom.name}
              </h1>
              <p class="text-secondary max-w-2xl mt-1 sm:mt-2 text-sm sm:text-base">
                {@classroom.description || gettext("No description")}
              </p>
            </div>

            <button
              phx-click="leave_classroom"
              data-confirm={gettext("Are you sure you want to leave this classroom?")}
              class="btn btn-error btn-outline btn-sm self-start"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 mr-1" /> {gettext("Leave")}
            </button>
          </div>
        </div>

        <%!-- My Stats Card --%>
        <div class="card bg-gradient-to-br from-primary/10 to-secondary/10 border border-primary/20 mb-6 sm:mb-8">
          <div class="card-body p-4 sm:p-6">
            <div class="flex items-center gap-3 sm:gap-4">
              <div class="w-12 h-12 sm:w-16 sm:h-16 bg-primary/20 rounded-full flex items-center justify-center shrink-0">
                <.icon name="hero-trophy" class="w-6 h-6 sm:w-8 sm:h-8 text-primary" />
              </div>
              <div class="min-w-0">
                <p class="text-xs sm:text-sm text-secondary">{gettext("My Points")}</p>
                <p class="text-2xl sm:text-3xl font-bold text-base-content">{@membership.points}</p>
              </div>
              <div class="ml-auto text-right">
                <p class="text-xs sm:text-sm text-secondary">{gettext("Rank")}</p>
                <p class="text-xl sm:text-2xl font-bold text-base-content">
                  #{get_rank(@members, @current_scope.current_user.id)}
                </p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Tabs - Scrollable on mobile --%>
        <div class="border-b border-base-300 mb-6 overflow-x-auto">
          <div class="flex gap-1 min-w-max">
            <.tab_button
              active={@active_tab == "overview"}
              tab="overview"
              label={gettext("Overview")}
            />
            <.tab_button
              active={@active_tab == "rankings"}
              tab="rankings"
              label={gettext("Rankings")}
            />
            <.tab_button active={@active_tab == "lessons"} tab="lessons" label={gettext("Lessons")} />
            <.tab_button active={@active_tab == "tests"} tab="tests" label={gettext("Tests")} />
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
      <div class="card-body p-4 sm:p-6">
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4">
          <h3 class="card-title text-lg sm:text-xl text-base-content">
            {gettext("Classroom Rankings")}
          </h3>
          <.link
            navigate={~p"/classrooms/#{@current_user.id}/rankings"}
            class="btn btn-primary btn-sm w-full sm:w-auto"
          >
            <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> {gettext("Full Rankings")}
          </.link>
        </div>
        <%= if @members == [] do %>
          <p class="text-secondary">{gettext("No members yet.")}</p>
        <% else %>
          <div class="space-y-2">
            <%= for {member, index} <- Enum.with_index(@members, 1) do %>
              <div class={[
                "flex items-center justify-between p-3 sm:p-4 rounded-xl",
                member.user_id == @current_user.id && "bg-primary/10 border border-primary/30"
              ]}>
                <div class="flex items-center gap-2 sm:gap-4 min-w-0 flex-1">
                  <span class={[
                    "w-8 h-8 sm:w-10 sm:h-10 rounded-lg sm:rounded-xl flex items-center justify-center font-bold text-sm shrink-0",
                    index == 1 && "bg-yellow-100 text-yellow-700",
                    index == 2 && "bg-gray-200 text-gray-700",
                    index == 3 && "bg-orange-100 text-orange-700",
                    index > 3 && "bg-base-200 text-secondary"
                  ]}>
                    {index}
                  </span>
                  <div class="w-8 h-8 sm:w-10 sm:h-10 bg-base-200 rounded-full flex items-center justify-center shrink-0">
                    <.icon name="hero-user" class="w-4 h-4 sm:w-5 sm:h-5 text-secondary" />
                  </div>
                  <div class="min-w-0">
                    <p class={[
                      "text-sm sm:text-base truncate",
                      member.user_id == @current_user.id && "font-medium text-base-content"
                    ]}>
                      {display_name(member.user, @current_user.id, @current_user.type == "admin")}
                      <%= if member.user_id == @current_user.id do %>
                        <span class="badge badge-primary badge-xs sm:badge-sm ml-1 sm:ml-2">
                          {gettext("You")}
                        </span>
                      <% end %>
                    </p>
                    <p class="text-xs sm:text-sm text-secondary">
                      {gettext("Joined")} {Calendar.strftime(
                        member.joined_at || member.inserted_at,
                        "%b %d, %Y"
                      )}
                    </p>
                  </div>
                </div>
                <span class="font-bold text-base sm:text-lg text-base-content ml-2 shrink-0">
                  {member.points} {gettext("pts")}
                </span>
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
    <div class="space-y-3 sm:space-y-4">
      <%= if @custom_lessons == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-book-open"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("No Lessons Available")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext(
              "Your teacher hasn't published any lessons to this classroom yet. Check back later!"
            )}
          </p>
        </div>
      <% else %>
        <%= for classroom_lesson <- @custom_lessons do %>
          <% lesson = classroom_lesson.custom_lesson %>
          <% progress = get_lesson_progress(@lesson_progress, lesson.id) %>
          <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body p-4 sm:p-6">
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 sm:gap-4">
                <div class="flex-1 min-w-0">
                  <h3 class="card-title text-base sm:text-lg text-base-content mb-1">
                    {lesson.title}
                  </h3>
                  <p class="text-secondary text-sm mb-2 sm:mb-3">
                    {lesson.description || gettext("No description")}
                  </p>

                  <div class="flex flex-wrap gap-2 sm:gap-3 text-xs sm:text-sm">
                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-bookmark" class="w-3 h-3 mr-1" />
                      {lesson.word_count} {gettext("words")}
                    </span>

                    <%= if lesson.difficulty do %>
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-signal" class="w-3 h-3 mr-1" /> N{lesson.difficulty}
                      </span>
                    <% end %>

                    <%= if lesson.requires_test do %>
                      <span class="badge badge-info badge-sm" title={gettext("Requires test to complete")}>
                        <.icon name="hero-pencil" class="w-3 h-3 mr-1" /> {gettext("Test")}
                      </span>
                    <% end %>

                    <%= case progress && progress.status do %>
                      <% "completed" -> %>
                        <span class="badge badge-success badge-sm">
                          <.icon name="hero-check" class="w-3 h-3 mr-1" /> {gettext("Completed")}
                        </span>
                      <% "in_progress" -> %>
                        <span class="badge badge-warning badge-sm">
                          <.icon name="hero-play" class="w-3 h-3 mr-1" /> {gettext("In Progress")}
                        </span>
                      <% _ -> %>
                        <span class="badge badge-ghost badge-sm">
                          {gettext("Not Started")}
                        </span>
                    <% end %>
                  </div>
                </div>

                <div class="sm:ml-4 self-start sm:self-auto">
                  <%= case progress && progress.status do %>
                    <% "completed" -> %>
                      <span class="badge badge-success">
                        +{progress.points_earned} {gettext("pts")}
                      </span>
                    <% _ -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{lesson.id}"}
                        class="btn btn-primary btn-sm sm:btn-md"
                      >
                        <%= if progress && progress.status == "in_progress" do %>
                          <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Continue")}
                        <% else %>
                          <.icon name="hero-book-open" class="w-4 h-4 mr-1" /> {gettext("Start")}
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
    <div class="space-y-3 sm:space-y-4">
      <%= if @published_tests == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-6 sm:p-8 text-center">
          <.icon
            name="hero-clipboard-document-list"
            class="w-12 h-12 sm:w-16 sm:h-16 text-secondary/20 mx-auto mb-3 sm:mb-4"
          />
          <h3 class="text-lg sm:text-xl font-semibold text-base-content mb-2">
            {gettext("No Tests Available")}
          </h3>
          <p class="text-secondary max-w-md mx-auto text-sm sm:text-base">
            {gettext(
              "Your teacher hasn't published any tests to this classroom yet. Check back later!"
            )}
          </p>
        </div>
      <% else %>
        <%= for classroom_test <- @published_tests do %>
          <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
            <div class="card-body p-4 sm:p-6">
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 sm:gap-4">
                <div class="flex-1 min-w-0">
                  <h3 class="card-title text-base sm:text-lg text-base-content mb-1">
                    {classroom_test.test.title}
                  </h3>
                  <p class="text-secondary text-sm mb-2 sm:mb-3">
                    {classroom_test.test.description || gettext("No description")}
                  </p>

                  <div class="flex flex-wrap gap-2 sm:gap-3 text-xs sm:text-sm">
                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-clock" class="w-3 h-3 mr-1" />
                      <%= if classroom_test.test.time_limit_seconds do %>
                        {format_duration(classroom_test.test.time_limit_seconds)}
                      <% else %>
                        {gettext("No time limit")}
                      <% end %>
                    </span>

                    <span class="badge badge-outline badge-sm">
                      <.icon name="hero-star" class="w-3 h-3 mr-1" />
                      {classroom_test.test.total_points} {gettext("points")}
                    </span>

                    <%= if classroom_test.max_attempts do %>
                      <span class="badge badge-outline badge-sm">
                        <.icon name="hero-arrow-path" class="w-3 h-3 mr-1" />
                        {classroom_test.max_attempts} {if classroom_test.max_attempts != 1,
                          do: gettext("attempts"),
                          else: gettext("attempt")}
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
                          {gettext("Overdue")}
                        <% else %>
                          {gettext("Due")} {Calendar.strftime(classroom_test.due_date, "%b %d")}
                        <% end %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <div class="sm:ml-4 self-start sm:self-auto">
                  <% attempt = get_attempt_for_test(@user_attempts, classroom_test.test_id) %>
                  <%= case get_test_status(@classroom.id, @current_user.id, classroom_test.test_id, attempt) do %>
                    <% :not_started -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-primary btn-sm sm:btn-md"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start Test")}
                      </.link>
                    <% :in_progress -> %>
                      <.link
                        navigate={~p"/classrooms/#{@classroom.id}/tests/#{classroom_test.test_id}"}
                        class="btn btn-warning btn-sm sm:btn-md"
                      >
                        <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Continue")}
                      </.link>
                    <% :completed -> %>
                      <span class="badge badge-success">
                        {gettext("Completed")} {attempt.score}/{attempt.max_score}
                      </span>
                    <% :timed_out -> %>
                      <span class="badge badge-error">{gettext("Timed Out")}</span>
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
        "px-3 sm:px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap",
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
