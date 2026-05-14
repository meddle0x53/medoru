defmodule MedoruWeb.Teacher.ClassroomLive.Show do
  @moduledoc """
  LiveView for teachers to manage a specific classroom.
  Includes tabs for Overview, Students, Lessons, Tests, and Settings.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.Components.Helpers, only: [format_relative_time: 1, display_name: 3]

  alias Medoru.Classrooms
  alias Medoru.Games
  alias Medoru.Notifications

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(id)

    # Verify teacher owns this classroom
    if classroom.teacher_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to access this classroom."))
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
    classroom_games = Games.list_classroom_games(classroom.id)

    socket
    |> assign(:page_title, classroom.name)
    |> assign(:classroom, classroom)
    |> assign(:stats, stats)
    |> assign(:members, members)
    |> assign(:pending_memberships, pending)
    |> assign(:published_tests, published_tests)
    |> assign(:test_attempts, test_attempts)
    |> assign(:classroom_games, classroom_games)
    |> assign(:active_tab, "overview")
    |> assign(:editing_settings, false)
    |> assign(:edit_name, classroom.name)
    |> assign(:edit_description, classroom.description || "")
    |> assign(:edit_should_approve_memberships, classroom.should_approve_memberships)
    |> assign(:edit_public, classroom.public)
    |> assign(:edit_errors, %{})
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"

    # Reload data when switching to specific tabs
    socket =
      case tab do
        "tests" ->
          classroom = socket.assigns.classroom
          published_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
          test_attempts = Classrooms.list_classroom_test_attempts(classroom.id, limit: 100)

          socket
          |> assign(:published_tests, published_tests)
          |> assign(:test_attempts, test_attempts)

        "lessons" ->
          classroom = socket.assigns.classroom
          load_lessons_data(socket, classroom)

        "games" ->
          classroom = socket.assigns.classroom
          games = Games.list_classroom_games(classroom.id)
          assign(socket, :classroom_games, games)

        _ ->
          socket
      end

    {:noreply, assign(socket, :active_tab, tab)}
  end

  defp load_lessons_data(socket, classroom) do
    result =
      Medoru.Content.list_classroom_custom_lessons(classroom.id, status: "active", per_page: 100)

    socket
    |> assign(:classroom_lessons, result.lessons)
    |> assign(:lessons_page, result.page)
    |> assign(:lessons_total_pages, result.total_pages)
    |> assign(:lessons_total_count, result.total_count)
    |> assign(:reordering, false)
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
          title: gettext("Application Approved"),
          message:
            gettext("You have been approved to join %{classroom}",
              classroom: socket.assigns.classroom.name
            ),
          data: %{classroom_id: socket.assigns.classroom.id}
        })

        socket = load_classroom_data(socket, socket.assigns.classroom)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Student approved successfully!"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to approve student."))}
    end
  end

  @impl true
  def handle_event("reject_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.reject_membership(membership) do
      {:ok, _} ->
        socket = load_classroom_data(socket, socket.assigns.classroom)
        {:noreply, put_flash(socket, :info, gettext("Application rejected."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reject application."))}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.remove_member(membership) do
      {:ok, _} ->
        socket = load_classroom_data(socket, socket.assigns.classroom)
        {:noreply, put_flash(socket, :info, gettext("Student removed from classroom."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove student."))}
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
         |> put_flash(:info, gettext("Invite code regenerated!"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to regenerate invite code."))}
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
         |> put_flash(:info, gettext("Classroom closed. No new students can join."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to close classroom."))}
    end
  end

  @impl true
  def handle_event("toggle_edit_settings", _, socket) do
    classroom = socket.assigns.classroom

    {:noreply,
     socket
     |> assign(:editing_settings, not socket.assigns.editing_settings)
     |> assign(:edit_name, classroom.name)
     |> assign(:edit_description, classroom.description || "")
     |> assign(:edit_should_approve_memberships, classroom.should_approve_memberships)
     |> assign(:edit_public, classroom.public)
     |> assign(:edit_errors, %{})}
  end

  @impl true
  def handle_event("update_classroom_field", %{} = params, socket) do
    field = params["field"] || List.first(params["_target"] || []) || ""
    value = params[field] || ""

    socket =
      case field do
        "name" -> assign(socket, :edit_name, value)
        "description" -> assign(socket, :edit_description, value)
        "should_approve_memberships" -> assign(socket, :edit_should_approve_memberships, value == "true")
        "public" -> assign(socket, :edit_public, value == "true")
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_classroom_settings", _params, socket) do
    classroom = socket.assigns.classroom
    teacher_id = socket.assigns.current_scope.current_user.id

    attrs = %{
      "name" => String.trim(socket.assigns.edit_name),
      "description" => String.trim(socket.assigns.edit_description),
      "should_approve_memberships" => socket.assigns.edit_should_approve_memberships,
      "public" => socket.assigns.edit_public
    }

    case Classrooms.update_classroom(classroom, teacher_id, attrs) do
      {:ok, updated_classroom} ->
        {:noreply,
         socket
         |> assign(:classroom, updated_classroom)
         |> assign(:page_title, updated_classroom.name)
         |> assign(:editing_settings, false)
         |> assign(:edit_errors, %{})
         |> put_flash(:info, gettext("Classroom updated successfully."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)
          |> Map.new()

        {:noreply,
         socket
         |> assign(:edit_errors, errors)
         |> put_flash(:error, gettext("Please fix the errors below."))}

      {:error, :not_authorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not authorized to update this classroom."))}
    end
  end

  @impl true
  def handle_event("cancel_edit_settings", _, socket) do
    classroom = socket.assigns.classroom

    {:noreply,
     socket
     |> assign(:editing_settings, false)
     |> assign(:edit_name, classroom.name)
     |> assign(:edit_description, classroom.description || "")
     |> assign(:edit_should_approve_memberships, classroom.should_approve_memberships)
     |> assign(:edit_public, classroom.public)
     |> assign(:edit_errors, %{})}
  end

  @impl true
  def handle_event("reset_test", %{"attempt_id" => attempt_id}, socket) do
    teacher_id = socket.assigns.current_scope.current_user.id
    classroom = socket.assigns.classroom

    case Classrooms.reset_test_attempt(attempt_id, teacher_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(
           :test_attempts,
           Classrooms.list_classroom_test_attempts(classroom.id, limit: 100)
         )
         |> put_flash(:info, gettext("Test reset successfully. Student can now retake it."))}

      {:error, :not_authorized} ->
        {:noreply,
         put_flash(socket, :error, gettext("You are not authorized to reset this test."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reset test."))}
    end
  end

  @impl true
  def handle_event("publish_game", %{"id" => game_id}, socket) do
    teacher_id = socket.assigns.current_scope.current_user.id

    case Games.publish_game(game_id, teacher_id) do
      {:ok, _} ->
        classroom = socket.assigns.classroom

        {:noreply,
         socket
         |> assign(:classroom_games, Games.list_classroom_games(classroom.id))
         |> put_flash(:info, gettext("Game published successfully."))}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to publish this game."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to publish game."))}
    end
  end

  @impl true
  def handle_event("unpublish_game", %{"id" => game_id}, socket) do
    teacher_id = socket.assigns.current_scope.current_user.id

    case Games.unpublish_game(game_id, teacher_id) do
      {:ok, _} ->
        classroom = socket.assigns.classroom

        {:noreply,
         socket
         |> assign(:classroom_games, Games.list_classroom_games(classroom.id))
         |> put_flash(:info, gettext("Game unpublished."))}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to unpublish this game."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to unpublish game."))}
    end
  end

  @impl true
  def handle_event("toggle_reordering", _, socket) do
    {:noreply, assign(socket, :reordering, not socket.assigns.reordering)}
  end

  @impl true
  def handle_event("move_lesson_up", %{"id" => lesson_id}, socket) do
    classroom_id = socket.assigns.classroom.id
    teacher_id = socket.assigns.current_scope.current_user.id

    # First ensure indices are initialized, then get fresh data
    with :ok <- Classrooms.ensure_lesson_order_indices(classroom_id),
         result =
           Medoru.Content.list_classroom_custom_lessons(classroom_id,
             status: "active",
             per_page: 100
           ),
         lessons = result.lessons,
         current_index = Enum.find_index(lessons, fn l -> l.id == lesson_id end),
         true <- current_index && current_index > 0 do
      current_lesson = Enum.at(lessons, current_index)
      prev_lesson = Enum.at(lessons, current_index - 1)

      new_order = [
        {current_lesson.id, prev_lesson.order_index},
        {prev_lesson.id, current_lesson.order_index}
      ]

      case Classrooms.reorder_classroom_lessons(classroom_id, teacher_id, new_order) do
        {:ok, _} ->
          result =
            Medoru.Content.list_classroom_custom_lessons(classroom_id,
              status: "active",
              per_page: 100
            )

          {:noreply, assign(socket, :classroom_lessons, result.lessons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to reorder lessons."))}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_lesson_down", %{"id" => lesson_id}, socket) do
    classroom_id = socket.assigns.classroom.id
    teacher_id = socket.assigns.current_scope.current_user.id

    # First ensure indices are initialized, then get fresh data
    with :ok <- Classrooms.ensure_lesson_order_indices(classroom_id),
         result =
           Medoru.Content.list_classroom_custom_lessons(classroom_id,
             status: "active",
             per_page: 100
           ),
         lessons = result.lessons,
         current_index = Enum.find_index(lessons, fn l -> l.id == lesson_id end),
         last_index = length(lessons) - 1,
         true <- current_index && current_index < last_index do
      current_lesson = Enum.at(lessons, current_index)
      next_lesson = Enum.at(lessons, current_index + 1)

      new_order = [
        {current_lesson.id, next_lesson.order_index},
        {next_lesson.id, current_lesson.order_index}
      ]

      case Classrooms.reorder_classroom_lessons(classroom_id, teacher_id, new_order) do
        {:ok, _} ->
          result =
            Medoru.Content.list_classroom_custom_lessons(classroom_id,
              status: "active",
              per_page: 100
            )

          {:noreply, assign(socket, :classroom_lessons, result.lessons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to reorder lessons."))}
      end
    else
      _ -> {:noreply, socket}
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
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Classrooms")}
          </.link>

          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold text-base-content">{@classroom.name}</h1>
                <.badge status={@classroom.status} />
              </div>
              <p class="text-secondary max-w-2xl">
                {@classroom.description || gettext("No description")}
              </p>
            </div>

            <%= if @classroom.status == :active do %>
              <button
                phx-click="close_classroom"
                data-confirm={
                  gettext(
                    "Are you sure you want to close this classroom? No new students will be able to join."
                  )
                }
                class="btn btn-warning btn-outline btn-sm"
              >
                <.icon name="hero-lock-closed" class="w-4 h-4 mr-1" /> {gettext("Close")}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <.stat_card
            icon="hero-users"
            label={gettext("Members")}
            value={@stats.total_members}
            color="blue"
          />
          <.stat_card
            icon="hero-clock"
            label={gettext("Pending")}
            value={@stats.pending_applications}
            color="warning"
          />
          <.stat_card
            icon="hero-trophy"
            label={gettext("Total Points")}
            value={@stats.total_points}
            color="purple"
          />
          <.stat_card
            icon="hero-calendar"
            label={gettext("Created")}
            value={Calendar.strftime(@classroom.inserted_at, "%b %d")}
            color="neutral"
          />
        </div>

        <%!-- Tabs --%>
        <div class="border-b border-base-300 mb-6">
          <div class="flex gap-1">
            <.tab_button
              active={@active_tab == "overview"}
              tab="overview"
              label={gettext("Overview")}
            />
            <.tab_button
              active={@active_tab == "students"}
              tab="students"
              badge={length(@pending_memberships)}
              label={gettext("Students")}
            />
            <.tab_button active={@active_tab == "lessons"} tab="lessons" label={gettext("Lessons")} />
            <.tab_button active={@active_tab == "tests"} tab="tests" label={gettext("Tests")} />
            <.tab_button active={@active_tab == "games"} tab="games" label={gettext("Games")} />
            <.tab_button
              active={@active_tab == "settings"}
              tab="settings"
              label={gettext("Settings")}
            />
          </div>
          <div class="ml-auto">
            <.link
              navigate={~p"/teacher/classrooms/#{@classroom.id}/analytics"}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> {gettext("Analytics")}
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
              <.lessons_tab
                classroom_lessons={@classroom_lessons}
                lessons_total_count={@lessons_total_count}
                reordering={@reordering}
              />
            <% "tests" -> %>
              <.tests_tab
                published_tests={@published_tests}
                test_attempts={@test_attempts}
                current_scope={@current_scope}
              />
            <% "games" -> %>
              <.games_tab
                classroom={@classroom}
                classroom_games={@classroom_games}
              />
            <% "settings" -> %>
              <.settings_tab
                classroom={@classroom}
                editing_settings={@editing_settings}
                edit_name={@edit_name}
                edit_description={@edit_description}
                edit_should_approve_memberships={@edit_should_approve_memberships}
                edit_public={@edit_public}
                edit_errors={@edit_errors}
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
      <%!-- Invite Code Card --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <h3 class="card-title text-base-content">{gettext("Invite Code")}</h3>
          <p class="text-secondary mb-4">
            {gettext("Share this code with students so they can join your classroom.")}
          </p>

          <div class="flex items-center gap-4">
            <div class="bg-base-200 px-6 py-3 rounded-xl font-mono text-xl tracking-wider text-base-content">
              {@invite_code}
            </div>
            <button phx-click="regenerate_invite_code" class="btn btn-ghost btn-outline">
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Regenerate")}
            </button>
          </div>
        </div>
      </div>

      <%!-- Quick Links --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-base-content">{gettext("Students")}</h3>
            <p class="text-secondary mb-4">{@stats.total_members} {gettext("approved members")}</p>
            <button phx-click="change_tab" phx-value-tab="students" class="btn btn-primary btn-sm">
              {gettext("Manage Students")}
            </button>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-base-content">{gettext("Classroom Rankings")}</h3>
            <p class="text-secondary mb-4">{gettext("View student progress and leaderboards")}</p>
            <button class="btn btn-primary btn-sm" disabled>
              {gettext("Coming Soon")}
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
              <.icon name="hero-clock" class="w-5 h-5" /> {gettext("Pending Applications")} ({length(
                @pending
              )})
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
            <h3 class="card-title text-base-content">{gettext("Classroom Members")}</h3>
            <span class="badge badge-ghost">{length(@members)} {gettext("members")}</span>
          </div>

          <%= if @members == [] do %>
            <div class="text-center py-8 text-secondary">
              <.icon name="hero-users" class="w-12 h-12 text-secondary/30 mx-auto mb-3" />
              <p>{gettext("No members yet. Share your invite code to get started.")}</p>
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

  attr :classroom_lessons, :list, required: true
  attr :lessons_total_count, :integer, required: true
  attr :reordering, :boolean, required: true

  defp lessons_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header with count and reorder toggle --%>
      <div class="flex items-center justify-between">
        <h3 class="card-title text-base-content">
          <.icon name="hero-book-open" class="w-5 h-5 mr-2" />
          {gettext("Published Lessons")}
          <span class="badge badge-ghost ml-2">{@lessons_total_count}</span>
        </h3>

        <div class="flex items-center gap-3">
          <%= if @classroom_lessons != [] do %>
            <button
              phx-click="toggle_reordering"
              class={[
                "btn btn-sm",
                @reordering && "btn-primary",
                !@reordering && "btn-ghost btn-outline"
              ]}
            >
              <%= if @reordering do %>
                <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
              <% else %>
                <.icon name="hero-arrows-up-down" class="w-4 h-4 mr-1" /> {gettext("Reorder")}
              <% end %>
            </button>
          <% end %>

          <.link navigate={~p"/teacher/custom-lessons"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Add Lessons")}
          </.link>
        </div>
      </div>

      <%= if @classroom_lessons == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
          <.icon name="hero-book-open" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h3 class="text-xl font-semibold text-base-content mb-2">{gettext("No Lessons Yet")}</h3>
          <p class="text-secondary max-w-md mx-auto mb-6">
            {gettext(
              "You haven't published any lessons to this classroom yet. Create and publish lessons to get started."
            )}
          </p>
          <.link navigate={~p"/teacher/custom-lessons"} class="btn btn-primary">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Create a Lesson")}
          </.link>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for {classroom_lesson, index} <- Enum.with_index(@classroom_lessons, 1) do %>
            <% lesson = classroom_lesson.custom_lesson %>
            <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
              <div class="card-body p-4">
                <div class="flex items-center gap-4">
                  <%= if @reordering do %>
                    <div class="flex flex-col gap-1">
                      <button
                        phx-click="move_lesson_up"
                        phx-value-id={classroom_lesson.id}
                        disabled={index == 1}
                        class={["btn btn-xs btn-ghost", index == 1 && "opacity-30"]}
                      >
                        <.icon name="hero-chevron-up" class="w-4 h-4" />
                      </button>
                      <button
                        phx-click="move_lesson_down"
                        phx-value-id={classroom_lesson.id}
                        disabled={index == @lessons_total_count}
                        class={["btn btn-xs btn-ghost", index == @lessons_total_count && "opacity-30"]}
                      >
                        <.icon name="hero-chevron-down" class="w-4 h-4" />
                      </button>
                    </div>
                  <% else %>
                    <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center text-primary font-bold">
                      {index}
                    </div>
                  <% end %>

                  <div class="flex-1 min-w-0">
                    <h4 class="font-semibold text-base-content truncate">{lesson.title}</h4>
                    <p class="text-sm text-secondary truncate">
                      {lesson.description || gettext("No description")}
                    </p>
                    <div class="flex flex-wrap gap-2 mt-2">
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
                        <span class="badge badge-info badge-sm">
                          <.icon name="hero-pencil" class="w-3 h-3 mr-1" /> {gettext("Test")}
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <.link
                      navigate={~p"/teacher/custom-lessons/#{lesson.id}/edit"}
                      class="btn btn-ghost btn-sm"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4" />
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :classroom_games, :list, required: true

  defp games_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h3 class="card-title text-base-content">
          <.icon name="hero-puzzle-piece" class="w-5 h-5 mr-2" />
          {gettext("Games")}
          <span class="badge badge-ghost ml-2">{length(@classroom_games)}</span>
        </h3>
        <div class="flex gap-2">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}/games/create"}
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Create Game")}
          </.link>
        </div>
      </div>

      <%= if @classroom_games == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
          <.icon name="hero-puzzle-piece" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h3 class="text-xl font-semibold text-base-content mb-2">{gettext("No Games Yet")}</h3>
          <p class="text-secondary max-w-md mx-auto mb-6">
            {gettext("Create memory card games to help your students practice vocabulary.")}
          </p>
          <div class="flex gap-2 justify-center">
            <.link navigate={~p"/teacher/classrooms/#{@classroom.id}/games/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Create Game")}
            </.link>
          </div>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for game <- @classroom_games do %>
            <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md transition-shadow">
              <div class="card-body p-4 sm:p-6">
                <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <h3 class="card-title text-base sm:text-lg text-base-content">{game.name}</h3>
                      <%= if game.status == :published do %>
                        <span class="badge badge-success badge-sm">{gettext("Published")}</span>
                      <% else %>
                        <span class="badge badge-ghost badge-sm">{gettext("Draft")}</span>
                      <% end %>
                    </div>
                    <%= cond do %>
                      <% game.memory_card_game -> %>
                        <div class="flex flex-wrap gap-2 text-xs sm:text-sm text-secondary">
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-squares-2x2" class="w-3 h-3 mr-1" />
                            {game.memory_card_game.board_size}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                            {game.memory_card_game.max_attempts} {gettext("attempts")}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-users" class="w-3 h-3 mr-1" />
                            {if game.max_players == 1,
                              do: gettext("Single Player"),
                              else: gettext("%{count} Players", count: game.max_players)}
                          </span>
                        </div>
                      <% game.kana_memory_card_game -> %>
                        <div class="flex flex-wrap gap-2 text-xs sm:text-sm text-secondary">
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-squares-2x2" class="w-3 h-3 mr-1" />
                            {game.kana_memory_card_game.board_size}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                            {game.kana_memory_card_game.max_attempts} {gettext("attempts")}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-language" class="w-3 h-3 mr-1" />
                            {length(game.kana_memory_card_game.selected_kana)} {gettext("kana")}
                          </span>
                          <%= if game.kana_memory_card_game.require_reading do %>
                            <span class="badge badge-outline badge-sm">
                              <.icon name="hero-pencil" class="w-3 h-3 mr-1" />
                              {gettext("Reading")}
                            </span>
                          <% end %>
                        </div>
                      <% game.kana_falling_game -> %>
                        <div class="flex flex-wrap gap-2 text-xs sm:text-sm text-secondary">
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-bolt" class="w-3 h-3 mr-1" />
                            {gettext("Speed")} {game.kana_falling_game.initial_speed}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                            {game.kana_falling_game.lives} {gettext("lives")}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-language" class="w-3 h-3 mr-1" />
                            {length(game.kana_falling_game.selected_kana)} {gettext("kana")}
                          </span>
                        </div>
                      <% game.kanji_falling_game -> %>
                        <div class="flex flex-wrap gap-2 text-xs sm:text-sm text-secondary">
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-bolt" class="w-3 h-3 mr-1" />
                            {gettext("Speed")} {game.kanji_falling_game.initial_speed}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-heart" class="w-3 h-3 mr-1" />
                            {game.kanji_falling_game.lives} {gettext("lives")}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-language" class="w-3 h-3 mr-1" />
                            {length(game.kanji_falling_game.selected_kanji)} {gettext("kanji")}
                          </span>
                          <span class="badge badge-outline badge-sm">
                            <.icon name="hero-pencil" class="w-3 h-3 mr-1" />
                            {game.kanji_falling_game.reading_type}
                          </span>
                        </div>
                      <% true -> %>
                    <% end %>
                  </div>
                  <div class="flex items-center gap-2 self-start">
                    <%= if game.status == :draft do %>
                      <button
                        phx-click="publish_game"
                        phx-value-id={game.id}
                        class="btn btn-success btn-sm"
                      >
                        <.icon name="hero-eye" class="w-4 h-4 mr-1" /> {gettext("Publish")}
                      </button>
                    <% else %>
                      <button
                        phx-click="unpublish_game"
                        phx-value-id={game.id}
                        class="btn btn-ghost btn-outline btn-sm"
                      >
                        <.icon name="hero-eye-slash" class="w-4 h-4 mr-1" /> {gettext("Unpublish")}
                      </button>
                    <% end %>
                    <.link
                      navigate={
                        case game.type do
                          "kana_memory_cards" ->
                            ~p"/teacher/classrooms/#{@classroom.id}/kana-games/#{game.id}"
                          "kana_falling" ->
                            ~p"/teacher/classrooms/#{@classroom.id}/kana-falling-games/#{game.id}"
                          "kanji_falling" ->
                            ~p"/teacher/classrooms/#{@classroom.id}/kanji-falling-games/#{game.id}"
                          _ ->
                            ~p"/teacher/classrooms/#{@classroom.id}/games/#{game.id}"
                        end
                      }
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-eye" class="w-4 h-4 mr-1" /> {gettext("View")}
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
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
            <.icon name="hero-clipboard-document-list" class="w-5 h-5" /> {gettext("Published Tests")}
          </h3>

          <%= if @published_tests == [] do %>
            <p class="text-secondary">{gettext("No tests published to this classroom yet.")}</p>
            <.link navigate={~p"/teacher/tests"} class="btn btn-primary btn-sm mt-4">
              <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Publish a Test")}
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
                  <span class="badge badge-success badge-sm">{gettext("Active")}</span>
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
            <.icon name="hero-users" class="w-5 h-5" /> {gettext("Student Attempts")}
          </h3>

          <%= if @test_attempts == [] do %>
            <p class="text-secondary">{gettext("No test attempts yet.")}</p>
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
                          {gettext("Reset")} {attempt.reset_count}x
                        </span>
                      <% end %>
                    </div>
                    <p class="text-sm text-secondary">
                      {attempt.test.title} • {attempt.score || 0}/{attempt.max_score} points
                    </p>
                    <p class="text-xs text-secondary mt-1">
                      <%= if attempt.completed_at do %>
                        {gettext("Completed")} {format_relative_time(attempt.completed_at)}
                      <% else %>
                        {gettext("Started")} {format_relative_time(attempt.started_at)}
                      <% end %>
                    </p>
                  </div>

                  <%!-- Reset Button --%>
                  <%= if attempt.status in ["completed", "timed_out"] do %>
                    <button
                      phx-click="reset_test"
                      phx-value-attempt_id={attempt.id}
                      data-confirm={
                        gettext("Reset this test for %{name}? They will be able to retake it.",
                          name: attempt.user.name
                        )
                      }
                      class="btn btn-warning btn-sm"
                    >
                      <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Reset")}
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

  attr :classroom, :map, required: true
  attr :editing_settings, :boolean, required: true
  attr :edit_name, :string, required: true
  attr :edit_description, :string, required: true
  attr :edit_should_approve_memberships, :boolean, required: true
  attr :edit_public, :boolean, required: true
  attr :edit_errors, :map, required: true

  defp settings_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm max-w-2xl">
      <div class="card-body">
        <div class="flex items-center justify-between mb-6">
          <h3 class="card-title text-base-content">{gettext("Classroom Settings")}</h3>
          <%= if not @editing_settings do %>
            <button phx-click="toggle_edit_settings" class="btn btn-ghost btn-sm">
              <.icon name="hero-pencil-square" class="w-4 h-4 mr-1" /> {gettext("Edit")}
            </button>
          <% end %>
        </div>

        <%= if @editing_settings do %>
          <form phx-submit="save_classroom_settings" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-base-content mb-1">
                {gettext("Classroom Name")}
              </label>
              <input
                type="text" name="name" value={@edit_name}
                phx-change="update_classroom_field" phx-value-field="name" phx-debounce="blur"
                class={["input input-bordered w-full", @edit_errors[:name] && "input-error"]}
              />
              <%= if @edit_errors[:name] do %>
                <p class="text-error text-sm mt-1">{@edit_errors[:name]}</p>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-base-content mb-1">
                {gettext("Description")}
              </label>
              <textarea
                name="description" rows="3"
                phx-change="update_classroom_field" phx-value-field="description" phx-debounce="blur"
                class={["textarea textarea-bordered w-full", @edit_errors[:description] && "textarea-error"]}
              >{@edit_description}</textarea>
              <%= if @edit_errors[:description] do %>
                <p class="text-error text-sm mt-1">{@edit_errors[:description]}</p>
              <% end %>
            </div>

            <div class="flex items-center gap-3 pt-2">
              <input
                type="checkbox" id="edit_should_approve_memberships"
                name="should_approve_memberships"
                checked={@edit_should_approve_memberships}
                phx-click="update_classroom_field"
                phx-value-field="should_approve_memberships"
                phx-value-should_approve_memberships={if @edit_should_approve_memberships, do: "false", else: "true"}
                class="checkbox checkbox-primary"
              />
              <label for="edit_should_approve_memberships" class="text-sm text-base-content cursor-pointer">
                {gettext("Require teacher approval for new members")}
              </label>
            </div>
            <p class="text-xs text-secondary -mt-2 ml-8">
              <%= if @edit_should_approve_memberships do %>
                <%= gettext("Students will apply and wait for your approval before joining.") %>
              <% else %>
                <%= gettext("Students will be added immediately without approval.") %>
              <% end %>
            </p>

            <div class="flex items-center gap-3 pt-2">
              <input
                type="checkbox" id="edit_public"
                name="public"
                checked={@edit_public}
                phx-click="update_classroom_field"
                phx-value-field="public"
                phx-value-public={if @edit_public, do: "false", else: "true"}
                class="checkbox checkbox-primary"
              />
              <label for="edit_public" class="text-sm text-base-content cursor-pointer">
                {gettext("Make classroom public")}
              </label>
            </div>
            <p class="text-xs text-secondary -mt-2 ml-8">
              <%= if @edit_public do %>
                <%= gettext("Anyone can find and join this classroom without an invite code.") %>
              <% else %>
                <%= gettext("Only students with the invite code can join this classroom.") %>
              <% end %>
            </p>

            <div class="flex gap-3 pt-2">
              <button type="button" phx-click="cancel_edit_settings" class="btn btn-ghost">
                {gettext("Cancel")}
              </button>
              <button type="submit" class="btn btn-primary">
                <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Save Changes")}
              </button>
            </div>
          </form>
        <% else %>
          <div class="space-y-4">
            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("Classroom Name")}</span>
              <span class="font-medium text-base-content">{@classroom.name}</span>
            </div>

            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("URL Slug")}</span>
              <span class="font-medium text-base-content">{@classroom.slug}</span>
            </div>

            <%= if @classroom.description && @classroom.description != "" do %>
              <div class="flex justify-between items-start py-3 border-b border-base-200">
                <span class="text-secondary">{gettext("Description")}</span>
                <span class="font-medium text-base-content text-right max-w-xs">
                  {@classroom.description}
                </span>
              </div>
            <% end %>

            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("Member Approval")}</span>
              <span class="font-medium text-base-content">
                <%= if @classroom.should_approve_memberships do %>
                  <%= gettext("Teacher approval required") %>
                <% else %>
                  <%= gettext("Auto-approve") %>
                <% end %>
              </span>
            </div>

            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("Visibility")}</span>
              <span class="font-medium text-base-content">
                <%= if @classroom.public do %>
                  <%= gettext("Public") %>
                <% else %>
                  <%= gettext("Private") %>
                <% end %>
              </span>
            </div>

            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("Status")}</span>
              <.badge status={@classroom.status} />
            </div>

            <div class="flex justify-between items-center py-3 border-b border-base-200">
              <span class="text-secondary">{gettext("Created")}</span>
              <span class="text-base-content">
                {Calendar.strftime(@classroom.inserted_at, "%B %d, %Y at %I:%M %p")}
              </span>
            </div>
          </div>
        <% end %>
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
    <span class="badge badge-success">{gettext("Active")}</span>
    """
  end

  defp badge(%{status: :archived} = assigns) do
    ~H"""
    <span class="badge badge-ghost">{gettext("Archived")}</span>
    """
  end

  defp badge(%{status: :closed} = assigns) do
    ~H"""
    <span class="badge badge-warning">{gettext("Closed")}</span>
    """
  end

  attr :membership, :map, required: true
  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false

  defp pending_member_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-base-100 rounded-xl p-4 border border-base-300">
      <div class="flex items-center gap-3">
        <% avatar_src =
          (@membership.user.profile && @membership.user.profile.avatar) || @membership.user.avatar_url %>
        <%= if avatar_src do %>
          <div class="avatar">
            <div class="w-10 h-10 rounded-full">
              <img src={avatar_src} alt="" class="object-cover" />
            </div>
          </div>
        <% else %>
          <div class="avatar placeholder">
            <div class="bg-primary text-primary-content rounded-full w-10 h-10 flex items-center justify-center">
              <% initial =
                if @membership.user.profile && @membership.user.profile.display_name,
                  do: String.first(@membership.user.profile.display_name) |> String.upcase(),
                  else:
                    String.first(@membership.user.name || @membership.user.email) |> String.upcase() %>
              <span class="text-sm">{initial}</span>
            </div>
          </div>
        <% end %>
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
          {gettext("Reject")}
        </button>
        <button
          phx-click="approve_member"
          phx-value-id={@membership.id}
          class="btn btn-success btn-sm"
        >
          {gettext("Approve")}
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
        <% avatar_src =
          (@membership.user.profile && @membership.user.profile.avatar) || @membership.user.avatar_url %>
        <%= if avatar_src do %>
          <div class="avatar">
            <div class="w-10 h-10 rounded-full">
              <img src={avatar_src} alt="" class="object-cover" />
            </div>
          </div>
        <% else %>
          <div class="avatar placeholder">
            <div class="bg-primary text-primary-content rounded-full w-10 h-10 flex items-center justify-center">
              <% initial =
                if @membership.user.profile && @membership.user.profile.display_name,
                  do: String.first(@membership.user.profile.display_name) |> String.upcase(),
                  else:
                    String.first(@membership.user.name || @membership.user.email) |> String.upcase() %>
              <span class="text-sm">{initial}</span>
            </div>
          </div>
        <% end %>
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
          data-confirm={gettext("Are you sure you want to remove this student?")}
          class="btn btn-ghost btn-sm text-error hover:bg-error/10"
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end
end
