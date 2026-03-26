defmodule MedoruWeb.Teacher.TestLive.Index do
  @moduledoc """
  LiveView for teachers to manage their tests.
  Shows a list of all tests with filtering by state.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Tests

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Only teachers and admins can access
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can manage tests."))
       |> push_navigate(to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:page_title, gettext("My Tests"))
       |> assign(:filter, "all")
       |> assign(:current_user, user)
       |> load_tests()}
    end
  end

  defp load_tests(socket) do
    user = socket.assigns.current_user
    filter = socket.assigns.filter

    tests =
      case filter do
        "all" -> Tests.list_teacher_tests(user.id)
        state -> Tests.list_teacher_tests(user.id, setup_state: state)
      end

    assign(socket, :tests, tests)
  end

  @impl true
  def handle_event("filter", %{"state" => state}, socket) do
    {:noreply,
     socket
     |> assign(:filter, state)
     |> load_tests()}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    test = Tests.get_test!(id)
    user = socket.assigns.current_user

    # Verify ownership
    if Tests.is_test_owner?(test, user.id) do
      case Tests.archive_teacher_test(test) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Test archived."))
           |> load_tests()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to archive test."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You can only archive your own tests."))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    test = Tests.get_test!(id)
    user = socket.assigns.current_user

    # Verify ownership and archived status
    if Tests.is_test_owner?(test, user.id) do
      if test.setup_state == "archived" do
        case Tests.delete_test(test) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Test deleted permanently."))
             |> load_tests()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to delete test."))}
        end
      else
        {:noreply, put_flash(socket, :error, gettext("Only archived tests can be deleted."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You can only delete your own tests."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4 mb-8">
          <div>
            <h1 class="text-2xl sm:text-3xl font-bold text-base-content">{gettext("My Tests")}</h1>
            <p class="text-secondary mt-1">{gettext("Create and manage your custom tests")}</p>
          </div>
          <.link navigate={~p"/teacher/tests/new"} class="w-full sm:w-auto">
            <button class="btn btn-primary w-full sm:w-auto">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Create Test")}
            </button>
          </.link>
        </div>

        <%!-- Filters --%>
        <div class="flex gap-2 mb-6 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0 sm:flex-wrap sm:overflow-visible sm:pb-0">
          <.filter_button
            active={@filter == "all"}
            click="filter"
            value="all"
            label={gettext("All")}
          />
          <.filter_button
            active={@filter == "in_progress"}
            click="filter"
            value="in_progress"
            label={gettext("In Progress")}
            color="info"
          />
          <.filter_button
            active={@filter == "ready"}
            click="filter"
            value="ready"
            label={gettext("Ready")}
            color="warning"
          />
          <.filter_button
            active={@filter == "published"}
            click="filter"
            value="published"
            label={gettext("Published")}
            color="success"
          />
          <.filter_button
            active={@filter == "archived"}
            click="filter"
            value="archived"
            label={gettext("Archived")}
            color="ghost"
          />
        </div>

        <%!-- Tests List --%>
        <%= if @tests == [] do %>
          <.empty_state filter={@filter} />
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for test <- @tests do %>
              <.test_card test={test} />
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  defp filter_button(%{color: "info"} = assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-state={@value}
      class={[
        "px-3 sm:px-4 py-2 sm:py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap",
        @active && "bg-info text-info-content",
        !@active && "bg-base-200 text-base-content hover:bg-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp filter_button(%{color: "warning"} = assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-state={@value}
      class={[
        "px-3 sm:px-4 py-2 sm:py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap",
        @active && "bg-warning text-warning-content",
        !@active && "bg-base-200 text-base-content hover:bg-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp filter_button(%{color: "success"} = assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-state={@value}
      class={[
        "px-3 sm:px-4 py-2 sm:py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap",
        @active && "bg-success text-success-content",
        !@active && "bg-base-200 text-base-content hover:bg-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp filter_button(%{color: "ghost"} = assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-state={@value}
      class={[
        "px-3 sm:px-4 py-2 sm:py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap",
        @active && "bg-base-300 text-base-content",
        !@active && "bg-base-200 text-base-content hover:bg-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp filter_button(assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-state={@value}
      class={[
        "px-3 sm:px-4 py-2 sm:py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap",
        @active && "bg-primary text-primary-content",
        !@active && "bg-base-200 text-base-content hover:bg-base-300"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm p-12 text-center">
      <.icon name="hero-clipboard-document-list" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
      <h3 class="text-xl font-semibold text-base-content mb-2">
        <%= case @filter do %>
          <% "all" -> %>
            {gettext("No tests yet")}
          <% "in_progress" -> %>
            {gettext("No tests in progress")}
          <% "ready" -> %>
            {gettext("No ready tests")}
          <% "published" -> %>
            {gettext("No published tests")}
          <% "archived" -> %>
            {gettext("No archived tests")}
          <% _ -> %>
            {gettext("No tests found")}
        <% end %>
      </h3>
      <p class="text-secondary mb-6">
        <%= case @filter do %>
          <% "all" -> %>
            {gettext("Create your first test to get started")}
          <% "in_progress" -> %>
            {gettext("Start creating a new test")}
          <% "ready" -> %>
            {gettext("Mark some tests as ready to publish")}
          <% "published" -> %>
            {gettext("Publish a ready test to make it available")}
          <% "archived" -> %>
            {gettext("Archive tests you no longer need")}
          <% _ -> %>
            {gettext("Try a different filter")}
        <% end %>
      </p>
      <%= if @filter == "all" or @filter == "in_progress" do %>
        <.link navigate={~p"/teacher/tests/new"} class="w-full sm:w-auto">
          <button class="btn btn-primary w-full sm:w-auto">
            <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Create Test
          </button>
        </.link>
      <% end %>
    </div>
    """
  end

  defp test_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">
      <div class="card-body">
        <div class="flex justify-between items-start mb-4">
          <.setup_state_badge state={@test.setup_state} />
          <div class="text-right">
            <p class="text-xs text-secondary">
              {Tests.count_test_steps(@test.id)} {gettext("steps")}
            </p>
          </div>
        </div>

        <h3 class="card-title text-base-content text-lg mb-2">
          <.link
            navigate={~p"/teacher/tests/#{@test.id}"}
            class="hover:text-primary transition-colors"
          >
            {@test.title}
          </.link>
        </h3>

        <p class="text-secondary text-sm mb-4 line-clamp-2">
          {@test.description || gettext("No description")}
        </p>

        <div class="flex items-center gap-4 text-sm text-secondary mb-4">
          <%= if @test.time_limit_seconds do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-clock" class="w-4 h-4" />
              <span>{format_time(@test.time_limit_seconds)}</span>
            </div>
          <% end %>
          <%= if @test.max_attempts do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-arrow-path" class="w-4 h-4" />
              <span>{@test.max_attempts} {gettext("attempts")}</span>
            </div>
          <% else %>
            <div class="flex items-center gap-1">
              <.icon name="hero-infinity" class="w-4 h-4" />
              <span>{gettext("Unlimited")}</span>
            </div>
          <% end %>
        </div>

        <div class="card-actions justify-end mt-4">
          <%= case @test.setup_state do %>
            <% "in_progress" -> %>
              <.link
                navigate={~p"/teacher/tests/#{@test.id}/edit"}
                class="btn btn-primary btn-sm w-full sm:w-auto"
              >
                <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> {gettext("Continue Editing")}
              </.link>
            <% "ready" -> %>
              <.link
                navigate={~p"/teacher/tests/#{@test.id}"}
                class="btn btn-primary btn-sm w-full sm:w-auto"
              >
                <.icon name="hero-eye" class="w-4 h-4 mr-1" /> {gettext("Review & Publish")}
              </.link>
            <% "published" -> %>
              <.link
                navigate={~p"/teacher/tests/#{@test.id}"}
                class="btn btn-success btn-sm w-full sm:w-auto"
              >
                <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" /> {gettext("View Results")}
              </.link>
            <% "archived" -> %>
              <div class="flex gap-2 w-full">
                <.link
                  navigate={~p"/teacher/tests/#{@test.id}"}
                  class="btn btn-ghost btn-sm flex-1"
                >
                  <.icon name="hero-eye" class="w-4 h-4 mr-1" /> {gettext("View")}
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={@test.id}
                  data-confirm={
                    gettext("Permanently delete this test? This action cannot be undone.")
                  }
                  class="btn btn-error btn-sm flex-1"
                >
                  <.icon name="hero-trash" class="w-4 h-4 mr-1" /> {gettext("Delete")}
                </button>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp setup_state_badge(%{state: "in_progress"} = assigns) do
    ~H"""
    <span class="badge badge-info">{gettext("In Progress")}</span>
    """
  end

  defp setup_state_badge(%{state: "ready"} = assigns) do
    ~H"""
    <span class="badge badge-warning">{gettext("Ready")}</span>
    """
  end

  defp setup_state_badge(%{state: "published"} = assigns) do
    ~H"""
    <span class="badge badge-success">{gettext("Published")}</span>
    """
  end

  defp setup_state_badge(%{state: "archived"} = assigns) do
    ~H"""
    <span class="badge badge-ghost">{gettext("Archived")}</span>
    """
  end

  defp setup_state_badge(assigns) do
    ~H"""
    <span class="badge">{@state}</span>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_time(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_time(seconds) when seconds < 3600 do
    "#{div(seconds, 60)}m"
  end

  defp format_time(seconds) do
    hours = div(seconds, 3600)
    mins = div(rem(seconds, 3600), 60)
    "#{hours}h #{mins}m"
  end
end
