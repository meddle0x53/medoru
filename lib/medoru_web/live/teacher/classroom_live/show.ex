defmodule MedoruWeb.Teacher.ClassroomLive.Show do
  @moduledoc """
  LiveView for teachers to manage a specific classroom.
  Includes tabs for Overview, Students, Lessons, Tests, and Settings.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.Components.Helpers, only: [format_relative_time: 1, display_name: 3]

  alias Medoru.Classrooms
  alias Medoru.Notifications

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(id)

    # Verify teacher owns this classroom
    if classroom.teacher_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this classroom.")
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      socket = load_classroom_data(socket, classroom)
      {:ok, socket}
    end
  end

  defp load_classroom_data(socket, classroom) do
    stats = Classrooms.get_classroom_stats(classroom.id)
    members = Classrooms.list_classroom_members(classroom.id)
    pending = Classrooms.list_pending_memberships(classroom.id)
    published_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
    test_attempts = Classrooms.list_classroom_test_attempts(classroom.id, limit: 100)

    socket
    |> assign(:page_title, classroom.name)
    |> assign(:classroom, classroom)
    |> assign(:stats, stats)
    |> assign(:members, members)
    |> assign(:pending_memberships, pending)
    |> assign(:published_tests, published_tests)
    |> assign(:test_attempts, test_attempts)
    |> assign(:active_tab, "overview")
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    
    # Reload data when switching to tests tab to get fresh attempt statuses
    socket =
      if tab == "tests" do
        classroom = socket.assigns.classroom
        published_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
        test_attempts = Classrooms.list_classroom_test_attempts(classroom.id, limit: 100)
        
        socket
        |> assign(:published_tests, published_tests)
        |> assign(:test_attempts, test_attempts)
      else
        socket
      end
    
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> push_patch(to: ~p"/teacher/classrooms/#{socket.assigns.classroom.id}?tab=#{tab}")}
  end

  @impl true
  def handle_event("approve_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.approve_membership(membership) do
      {:ok, approved_membership} ->
        # Notify the student
        Notifications.create_notification(%{
          user_id: approved_membership.user_id,
          type: :classroom,
          title: "Application Approved",
          message: "You have been approved to join #{socket.assigns.classroom.name}",
          data: %{classroom_id: socket.assigns.classroom.id}
        })

        socket = load_classroom_data(socket, socket.assigns.classroom)

        {:noreply,
         socket
         |> put_flash(:info, "Student approved successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve student.")}
    end
  end

  @impl true
  def handle_event("reject_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.reject_membership(membership) do
      {:ok, _} ->
        socket = load_classroom_data(socket, socket.assigns.classroom)
        {:noreply, put_flash(socket, :info, "Application rejected.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject application.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.remove_member(membership) do
      {:ok, _} ->
        socket = load_classroom_data(socket, socket.assigns.classroom)
        {:noreply, put_flash(socket, :info, "Student removed from classroom.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove student.")}
    end
  end

  @impl true
  def handle_event("regenerate_invite_code", _, socket) do
    classroom = socket.assigns.classroom

    case Classrooms.regenerate_invite_code(classroom) do
      {:ok, updated_classroom} ->
        {:noreply,
         socket
         |> assign(:classroom, updated_classroom)
         |> put_flash(:info, "Invite code regenerated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to regenerate invite code.")}
    end
  end

  @impl true
  def handle_event("close_classroom", _, socket) do
    classroom = socket.assigns.classroom

    case Classrooms.close_classroom(classroom) do
      {:ok, updated_classroom} ->
        {:noreply,
         socket
         |> assign(:classroom, updated_classroom)
         |> put_flash(:info, "Classroom closed. No new students can join.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to close classroom.")}
    end
  end

  @impl true
  def handle_event("reset_test", %{"attempt_id" => attempt_id}, socket) do
    teacher_id = socket.assigns.current_scope.current_user.id
    classroom = socket.assigns.classroom

    case Classrooms.reset_test_attempt(attempt_id, teacher_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:test_attempts, Classrooms.list_classroom_test_attempts(classroom.id, limit: 100))
         |> put_flash(:info, "Test reset successfully. Student can now retake it.")}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to reset this test.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset test.")}
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
            navigate={~p"/teacher/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Classrooms
          </.link>

          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold text-base-content">{@classroom.name}</h1>
                <.badge status={@classroom.status} />
              </div>
              <p class="text-secondary max-w-2xl">{@classroom.description || "No description"}</p>
            </div>

            <%= if @classroom.status == :active do %>
              <button
                phx-click="close_classroom"
                data-confirm="Are you sure you want to close this classroom? No new students will be able to join."
                class="btn btn-warning btn-outline btn-sm"
              >
                <.icon name="hero-lock-closed" class="w-4 h-4 mr-1" /> Close
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <.stat_card icon="hero-users" label="Members" value={@stats.total_members} color="blue" />
          <.stat_card
            icon="hero-clock"
            label="Pending"
            value={@stats.pending_applications}
            color="warning"
          />
          <.stat_card
            icon="hero-trophy"
            label="Total Points"
            value={@stats.total_points}
            color="purple"
          />
          <.stat_card
            icon="hero-calendar"
            label="Created"
            value={Calendar.strftime(@classroom.inserted_at, "%b %d")}
            color="neutral"
          />
        </div>

        <%!-- Tabs --%>
        <div class="border-b border-base-300 mb-6">
          <div class="flex gap-1">
            <.tab_button active={@active_tab == "overview"} tab="overview" label="Overview" />
            <.tab_button
              active={@active_tab == "students"}
              tab="students"
              badge={length(@pending_memberships)}
              label="Students"
            />
            <.tab_button active={@active_tab == "lessons"} tab="lessons" label="Lessons" />
            <.tab_button active={@active_tab == "tests"} tab="tests" label="Tests" />
            <.tab_button active={@active_tab == "settings"} tab="settings" label="Settings" />
          </div>
          <div class="ml-auto">
            <.link
              navigate={~p"/teacher/classrooms/#{@classroom.id}/analytics"}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> Analytics
            </.link>
          </div>
        </div>

        <%!-- Tab Content --%>
        <div class="min-h-[400px]">
          <%= case @active_tab do %>
            <% "overview" -> %>
              <.overview_tab
                classroom={@classroom}
                stats={@stats}
                invite_code={@classroom.invite_code}
              />
            <% "students" -> %>
              <.students_tab
                members={@members}
                pending={@pending_memberships}
                current_scope={@current_scope}
              />
            <% "lessons" -> %>
              <.lessons_tab />
            <% "tests" -> %>
              <.tests_tab
                published_tests={@published_tests}
                test_attempts={@test_attempts}
                current_scope={@current_scope}
              />
            <% "settings" -> %>
              <.settings_tab classroom={@classroom} />
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
      <%!-- Invite Code Card --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content">Invite Code</h3>
          <p class="text-secondary mb-4">
            Share this code with students so they can join your classroom.
          </p>

          <div class="flex items-center gap-4">
            <div class="bg-base-200 px-6 py-3 rounded-xl font-mono text-xl tracking-wider text-base-content">
              {@invite_code}
            </div>
            <button phx-click="regenerate_invite_code" class="btn btn-ghost btn-outline">
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> Regenerate
            </button>
          </div>
        </div>
      </div>

      <%!-- Quick Links --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-base-content">Students</h3>
            <p class="text-secondary mb-4">{@stats.total_members} approved members</p>
            <button phx-click="change_tab" phx-value-tab="students" class="btn btn-primary btn-sm">
              Manage Students
            </button>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-base-content">Classroom Rankings</h3>
            <p class="text-secondary mb-4">View student progress and leaderboards</p>
            <button class="btn btn-primary btn-sm" disabled>
              Coming Soon
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :members, :list, required: true
  attr :pending, :list, required: true
  attr :current_scope, :map, required: true

  defp students_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Pending Applications --%>
      <%= if @pending != [] do %>
        <div class="card bg-warning/10 border border-warning/30">
          <div class="card-body">
            <h3 class="card-title text-warning flex items-center gap-2">
              <.icon name="hero-clock" class="w-5 h-5" /> Pending Applications ({length(@pending)})
            </h3>
            <div class="space-y-3 mt-4">
              <%= for membership <- @pending do %>
                <.pending_member_row
                  membership={membership}
                  current_user={@current_scope.current_user}
                  is_admin={@current_scope.current_user.type == "admin"}
                />
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Approved Members --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <div class="flex justify-between items-center mb-4">
            <h3 class="card-title text-base-content">Classroom Members</h3>
            <span class="badge badge-ghost">{length(@members)} members</span>
          </div>

          <%= if @members == [] do %>
            <div class="text-center py-8 text-secondary">
              <.icon name="hero-users" class="w-12 h-12 text-secondary/30 mx-auto mb-3" />
              <p>No members yet. Share your invite code to get started.</p>
            </div>
          <% else %>
            <div class="space-y-2">
              <%= for membership <- @members do %>
                <.member_row
                  membership={membership}
                  current_user={@current_scope.current_user}
                  is_admin={@current_scope.current_user.type == "admin"}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp lessons_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
      <.icon name="hero-book-open" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
      <h3 class="text-xl font-semibold text-base-content mb-2">Lessons Coming Soon</h3>
      <p class="text-secondary max-w-md mx-auto">
        In the next iteration, you'll be able to assign lessons to your classroom and track student progress.
      </p>
    </div>
    """
  end

  attr :published_tests, :list, required: true
  attr :test_attempts, :list, required: true
  attr :current_scope, :map, required: true

  defp tests_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Published Tests --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">
            <.icon name="hero-clipboard-document-list" class="w-5 h-5" /> Published Tests
          </h3>

          <%= if @published_tests == [] do %>
            <p class="text-secondary">No tests published to this classroom yet.</p>
            <.link navigate={~p"/teacher/tests"} class="btn btn-primary btn-sm mt-4">
              <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Publish a Test
            </.link>
          <% else %>
            <div class="space-y-3">
              <%= for classroom_test <- @published_tests do %>
                <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                  <div>
                    <p class="font-medium text-base-content">{classroom_test.test.title}</p>
                    <div class="flex gap-4 text-sm text-secondary mt-1">
                      <span>{classroom_test.test.total_points} points</span>
                      <%= if classroom_test.due_date do %>
                        <span>Due: {Calendar.strftime(classroom_test.due_date, "%b %d, %Y")}</span>
                      <% end %>
                    </div>
                  </div>
                  <span class="badge badge-success badge-sm">Active</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Student Test Attempts --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content mb-4">
            <.icon name="hero-users" class="w-5 h-5" /> Student Attempts
          </h3>

          <%= if @test_attempts == [] do %>
            <p class="text-secondary">No test attempts yet.</p>
          <% else %>
            <div class="space-y-3">
              <%= for attempt <- @test_attempts do %>
                <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                  <div class="flex-1">
                    <div class="flex items-center gap-3 mb-1">
                      <p class="font-medium text-base-content">{attempt.user.name}</p>
                      <span class={[
                        "badge badge-sm",
                        attempt.status == "completed" && "badge-success",
                        attempt.status == "in_progress" && "badge-warning",
                        attempt.status == "timed_out" && "badge-error"
                      ]}>
                        {attempt.status |> String.replace("_", " ") |> String.capitalize()}
                      </span>
                      <%= if attempt.reset_count > 0 do %>
                        <span class="badge badge-info badge-sm">
                          Reset {attempt.reset_count}x
                        </span>
                      <% end %>
                    </div>
                    <p class="text-sm text-secondary">
                      {attempt.test.title} • {attempt.score || 0}/{attempt.max_score} points
                    </p>
                    <p class="text-xs text-secondary mt-1">
                      <%= if attempt.completed_at do %>
                        Completed {format_relative_time(attempt.completed_at)}
                      <% else %>
                        Started {format_relative_time(attempt.started_at)}
                      <% end %>
                    </p>
                  </div>

                  <%!-- Reset Button --%>
                  <%= if attempt.status in ["completed", "timed_out"] do %>
                    <button
                      phx-click="reset_test"
                      phx-value-attempt_id={attempt.id}
                      data-confirm="Reset this test for {attempt.user.name}? They will be able to retake it."
                      class="btn btn-warning btn-sm"
                    >
                      <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> Reset
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp settings_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm max-w-2xl">
      <div class="card-body">
        <h3 class="card-title text-base-content mb-6">Classroom Settings</h3>

        <div class="space-y-4">
          <div class="flex justify-between items-center py-3 border-b border-base-200">
            <span class="text-secondary">Classroom Name</span>
            <span class="font-medium text-base-content">{@classroom.name}</span>
          </div>

          <div class="flex justify-between items-center py-3 border-b border-base-200">
            <span class="text-secondary">URL Slug</span>
            <span class="font-medium text-base-content">{@classroom.slug}</span>
          </div>

          <div class="flex justify-between items-center py-3 border-b border-base-200">
            <span class="text-secondary">Status</span>
            <.badge status={@classroom.status} />
          </div>

          <div class="flex justify-between items-center py-3 border-b border-base-200">
            <span class="text-secondary">Created</span>
            <span class="text-base-content">
              {Calendar.strftime(@classroom.inserted_at, "%B %d, %Y at %I:%M %p")}
            </span>
          </div>

          <div class="pt-4">
            <p class="text-sm text-secondary">
              Advanced settings like editing classroom details will be available in future updates.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helper Components
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

  defp stat_card(%{color: "warning"} = assigns) do
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

  defp stat_card(%{color: "neutral"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex flex-row items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-base-200 text-secondary">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :label, :string, required: true
  attr :badge, :integer, default: nil

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={[
        "px-4 py-3 text-sm font-medium border-b-2 transition-colors flex items-center gap-2",
        @active && "border-primary text-primary",
        !@active && "border-transparent text-secondary hover:text-base-content hover:border-base-300"
      ]}
    >
      {@label}
      <%= if @badge && @badge > 0 do %>
        <span class="badge badge-warning badge-sm">{@badge}</span>
      <% end %>
    </button>
    """
  end

  defp badge(%{status: :active} = assigns) do
    ~H"""
    <span class="badge badge-success">Active</span>
    """
  end

  defp badge(%{status: :archived} = assigns) do
    ~H"""
    <span class="badge badge-ghost">Archived</span>
    """
  end

  defp badge(%{status: :closed} = assigns) do
    ~H"""
    <span class="badge badge-warning">Closed</span>
    """
  end

  attr :membership, :map, required: true
  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false

  defp pending_member_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-base-100 rounded-xl p-4 border border-base-300">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
          <.icon name="hero-user" class="w-5 h-5 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">
            {display_name(@membership.user, @current_user.id, @is_admin)}
          </p>
          <p class="text-sm text-secondary">
            Applied {format_relative_time(@membership.inserted_at)}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button
          phx-click="reject_member"
          phx-value-id={@membership.id}
          class="btn btn-ghost btn-sm"
        >
          Reject
        </button>
        <button
          phx-click="approve_member"
          phx-value-id={@membership.id}
          class="btn btn-success btn-sm"
        >
          Approve
        </button>
      </div>
    </div>
    """
  end

  attr :membership, :map, required: true
  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false

  defp member_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 hover:bg-base-200/50 rounded-xl transition-colors">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
          <.icon name="hero-user" class="w-5 h-5 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">
            {display_name(@membership.user, @current_user.id, @is_admin)}
          </p>
          <p class="text-sm text-secondary">
            Joined {Calendar.strftime(@membership.joined_at || @membership.inserted_at, "%b %d, %Y")}
          </p>
        </div>
      </div>
      <div class="flex items-center gap-4">
        <div class="text-right">
          <p class="font-semibold text-base-content">{@membership.points} pts</p>
          <p class="text-xs text-secondary capitalize">{@membership.role}</p>
        </div>
        <button
          phx-click="remove_member"
          phx-value-id={@membership.id}
          data-confirm="Are you sure you want to remove this student?"
          class="btn btn-ghost btn-sm text-error hover:bg-error/10"
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end
end
