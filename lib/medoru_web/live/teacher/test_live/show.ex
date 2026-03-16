defmodule MedoruWeb.Teacher.TestLive.Show do
  @moduledoc """
  LiveView for showing a teacher test and managing its state.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Tests
  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    test = Tests.get_test!(id)

    # Verify ownership
    if not Tests.is_test_owner?(test, user.id) do
      {:ok,
       socket
       |> put_flash(:error, gettext("You can only view your own tests."))
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      step_count = Tests.count_test_steps(test.id)
      published_classrooms = Classrooms.list_test_classrooms(test.id, status: nil)

      {:ok,
       socket
       |> assign(:page_title, test.title)
       |> assign(:test, test)
       |> assign(:step_count, step_count)
       |> assign(:published_classrooms, published_classrooms)
       |> assign(:current_user, user)}
    end
  end

  @impl true
  def handle_event("mark_ready", _, socket) do
    test = socket.assigns.test

    case Tests.mark_test_ready(test) do
      {:ok, updated_test} ->
        {:noreply,
         socket
         |> assign(:test, updated_test)
         |> put_flash(:info, gettext("Test marked as ready to publish!"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update test."))}
    end
  end

  @impl true
  def handle_event("publish", _, socket) do
    test = socket.assigns.test

    case Tests.publish_teacher_test(test) do
      {:ok, updated_test} ->
        {:noreply,
         socket
         |> assign(:test, updated_test)
         |> put_flash(:info, gettext("Test published! Students can now take it."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to publish test."))}
    end
  end

  @impl true
  def handle_event("archive", _, socket) do
    test = socket.assigns.test

    case Tests.archive_teacher_test(test) do
      {:ok, updated_test} ->
        {:noreply,
         socket
         |> assign(:test, updated_test)
         |> put_flash(:info, gettext("Test archived."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to archive test."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/tests"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to My Tests")}
          </.link>

          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold text-base-content">{@test.title}</h1>
                <.setup_state_badge state={@test.setup_state} />
              </div>
              <p class="text-secondary max-w-xl">
                {@test.description || gettext("No description")}
              </p>
            </div>

            <%!-- Actions based on state --%>
            <div class="flex gap-2">
              <%= case @test.setup_state do %>
                <% "in_progress" -> %>
                  <.link navigate={~p"/teacher/tests/#{@test.id}/edit"} class="btn btn-primary">
                    <.icon name="hero-pencil" class="w-4 h-4 mr-2" /> Edit Test
                  </.link>
                <% "ready" -> %>
                  <.link navigate={~p"/teacher/tests/#{@test.id}/publish"} class="btn btn-success">
                    <.icon name="hero-rocket-launch" class="w-4 h-4 mr-2" /> Publish
                  </.link>
                  <.link navigate={~p"/teacher/tests/#{@test.id}/edit"} class="btn btn-ghost">
                    <.icon name="hero-pencil" class="w-4 h-4" />
                  </.link>
                <% "published" -> %>
                  <button
                    phx-click="archive"
                    class="btn btn-warning"
                    data-confirm={
                      gettext("Archive this test? It won't be available to students anymore.")
                    }
                  >
                    <.icon name="hero-archive-box" class="w-4 h-4 mr-2" /> Archive
                  </button>
                <% "archived" -> %>
                  <button phx-click="publish" class="btn btn-success">
                    <.icon name="hero-rocket-launch" class="w-4 h-4 mr-2" /> Republish
                  </button>
              <% end %>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Stats Cards --%>
            <div class="grid grid-cols-3 gap-4">
              <div class="card bg-base-100 border border-base-300 p-4 text-center">
                <p class="text-3xl font-bold text-base-content">{@step_count}</p>
                <p class="text-sm text-secondary">{gettext("Steps")}</p>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 text-center">
                <p class="text-3xl font-bold text-base-content">
                  <%= if @test.time_limit_seconds do %>
                    {format_time_short(@test.time_limit_seconds)}
                  <% else %>
                    ∞
                  <% end %>
                </p>
                <p class="text-sm text-secondary">{gettext("Time Limit")}</p>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 text-center">
                <p class="text-3xl font-bold text-base-content">
                  <%= if @test.max_attempts do %>
                    {@test.max_attempts}
                  <% else %>
                    ∞
                  <% end %>
                </p>
                <p class="text-sm text-secondary">{gettext("Max Attempts")}</p>
              </div>
            </div>

            <%!-- Steps Preview --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="card-title text-base-content">{gettext("Test Steps")}</h2>
                  <%= if @test.setup_state == "in_progress" do %>
                    <.link
                      navigate={~p"/teacher/tests/#{@test.id}/edit"}
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-plus" class="w-4 h-4 mr-1" /> {gettext("Add Steps")}
                    </.link>
                  <% end %>
                </div>

                <%= if @step_count == 0 do %>
                  <div class="text-center py-8 text-secondary">
                    <.icon
                      name="hero-clipboard-document-list"
                      class="w-12 h-12 mx-auto mb-3 opacity-50"
                    />
                    <p>{gettext("No steps yet.")}</p>
                    <%= if @test.setup_state == "in_progress" do %>
                      <.link
                        navigate={~p"/teacher/tests/#{@test.id}/edit"}
                        class="btn btn-primary btn-sm mt-4"
                      >
                        {gettext("Add Your First Step")}
                      </.link>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-secondary">
                    {gettext("This test has %{count} step", count: @step_count)}{if @step_count != 1,
                      do: gettext("s")}.
                  </p>
                  <%= if @test.setup_state == "in_progress" do %>
                    <.link
                      navigate={~p"/teacher/tests/#{@test.id}/edit"}
                      class="btn btn-ghost btn-sm mt-4"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> {gettext("Manage Steps")}
                    </.link>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- State Info --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-base-content text-base mb-4">{gettext("Test Status")}</h3>
                <.state_info state={@test.setup_state} step_count={@step_count} />
              </div>
            </div>

            <%!-- Publishing Info --%>
            <%= if @test.setup_state == "ready" do %>
              <div class="card bg-success/10 border border-success/30">
                <div class="card-body">
                  <h3 class="card-title text-success text-base mb-2">
                    <.icon name="hero-check-circle" class="w-5 h-5" /> {gettext("Ready to Publish")}
                  </h3>
                  <p class="text-sm text-base-content mb-4">
                    {gettext("Your test is complete and ready for students.")}
                  </p>
                  <.link
                    navigate={~p"/teacher/tests/#{@test.id}/publish"}
                    class="btn btn-success btn-block"
                  >
                    <.icon name="hero-rocket-launch" class="w-4 h-4 mr-2" /> {gettext("Publish Now")}
                  </.link>
                </div>
              </div>
            <% end %>

            <%!-- Published Classrooms --%>
            <%= if @published_classrooms != [] do %>
              <div class="card bg-base-100 border border-base-300 shadow-sm">
                <div class="card-body">
                  <h3 class="card-title text-base-content text-base mb-4">
                    <.icon name="hero-academic-cap" class="w-5 h-5" /> {gettext("Published To")}
                  </h3>
                  <div class="space-y-2">
                    <%= for classroom_test <- @published_classrooms do %>
                      <div class="flex items-center justify-between p-2 bg-base-200 rounded-lg">
                        <span class="text-sm font-medium truncate">
                          {classroom_test.classroom.name}
                        </span>
                        <span class={[
                          "badge badge-xs",
                          classroom_test.status == :active && "badge-success",
                          classroom_test.status == :unpublished && "badge-warning",
                          classroom_test.status == :archived && "badge-ghost"
                        ]}>
                          {classroom_test.status}
                        </span>
                      </div>
                    <% end %>
                  </div>
                  <%= if @test.setup_state in ["ready", "published"] do %>
                    <.link
                      navigate={~p"/teacher/tests/#{@test.id}/publish"}
                      class="btn btn-ghost btn-sm btn-block mt-4"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> {gettext("Manage Publishing")}
                    </.link>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%!-- Danger Zone --%>
            <%= if @test.setup_state in ["ready", "published"] do %>
              <div class="card bg-error/5 border border-error/20">
                <div class="card-body">
                  <h3 class="card-title text-error text-base">{gettext("Danger Zone")}</h3>
                  <p class="text-sm text-secondary mb-4">
                    {gettext("Archiving removes this test from student access.")}
                  </p>
                  <button
                    phx-click="archive"
                    data-confirm={gettext("Are you sure you want to archive this test?")}
                    class="btn btn-error btn-outline btn-sm btn-block"
                  >
                    <.icon name="hero-archive-box" class="w-4 h-4 mr-2" /> Archive Test
                  </button>
                </div>
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

  defp state_info(%{state: "in_progress", step_count: 0} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-info/20 flex items-center justify-center flex-shrink-0">
          <span class="text-info font-bold text-sm">1</span>
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Create Test")}</p>
          <p class="text-sm text-secondary">{gettext("✓ Done")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center flex-shrink-0">
          <span class="text-primary font-bold text-sm">2</span>
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Add Steps")}</p>
          <p class="text-sm text-secondary">{gettext("Add questions to your test")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3 opacity-50">
        <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center flex-shrink-0">
          <span class="text-secondary font-bold text-sm">3</span>
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Publish")}</p>
          <p class="text-sm text-secondary">{gettext("Make it available to students")}</p>
        </div>
      </div>
    </div>
    """
  end

  defp state_info(%{state: "in_progress"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Create Test")}</p>
          <p class="text-sm text-secondary">{gettext("✓ Done")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">Add Steps</p>
          <p class="text-sm text-secondary">
            {gettext("✓ %{count} steps added", count: @step_count)}
          </p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center flex-shrink-0">
          <span class="text-primary font-bold text-sm">3</span>
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Mark as Ready")}</p>
          <button phx-click="mark_ready" class="btn btn-primary btn-sm mt-2">
            {gettext("Mark Ready")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp state_info(%{state: "ready"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Create Test")}</p>
          <p class="text-sm text-secondary">{gettext("✓ Done")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">Add Steps</p>
          <p class="text-sm text-secondary">{gettext("✓ %{count} steps", count: @step_count)}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-warning/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-clock" class="w-4 h-4 text-warning" />
        </div>
        <div>
          <p class="font-medium text-base-content">Publish</p>
          <p class="text-sm text-secondary">{gettext("Ready to go live!")}</p>
        </div>
      </div>
    </div>
    """
  end

  defp state_info(%{state: "published"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Create Test")}</p>
          <p class="text-sm text-secondary">{gettext("✓ Done")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">Add Steps</p>
          <p class="text-sm text-secondary">✓ {@step_count} steps</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">Published</p>
          <p class="text-sm text-secondary">{gettext("Live and available")}</p>
        </div>
      </div>
    </div>
    """
  end

  defp state_info(%{state: "archived"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">Create Test</p>
          <p class="text-sm text-secondary">{gettext("Completed")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">Published</p>
          <p class="text-sm text-secondary">{gettext("Was live")}</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-error/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-archive-box" class="w-4 h-4 text-error" />
        </div>
        <div>
          <p class="font-medium text-base-content">{gettext("Archived")}</p>
          <p class="text-sm text-secondary">{gettext("No longer available")}</p>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_time_short(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_time_short(seconds) when seconds < 3600 do
    "#{div(seconds, 60)}m"
  end

  defp format_time_short(seconds) do
    "#{div(seconds, 3600)}h"
  end
end
