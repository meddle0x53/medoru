defmodule MedoruWeb.Teacher.TestLive.Show do
  @moduledoc """
  LiveView for showing a teacher test and managing its state.
  """
  use MedoruWeb, :live_view

  alias Medoru.Tests

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    test = Tests.get_test!(id)

    # Verify ownership
    if not Tests.is_test_owner?(test, user.id) do
      {:ok,
       socket
       |> put_flash(:error, "You can only view your own tests.")
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      step_count = Tests.count_test_steps(test.id)

      {:ok,
       socket
       |> assign(:page_title, test.title)
       |> assign(:test, test)
       |> assign(:step_count, step_count)
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
         |> put_flash(:info, "Test marked as ready to publish!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update test.")}
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
         |> put_flash(:info, "Test published! Students can now take it.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to publish test.")}
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
         |> put_flash(:info, "Test archived.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to archive test.")}
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
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to My Tests
          </.link>

          <div class="flex items-start justify-between">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold text-base-content">{@test.title}</h1>
                <.setup_state_badge state={@test.setup_state} />
              </div>
              <p class="text-secondary max-w-xl">
                {@test.description || "No description"}
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
                  <button phx-click="publish" class="btn btn-success">
                    <.icon name="hero-rocket-launch" class="w-4 h-4 mr-2" /> Publish
                  </button>
                  <.link navigate={~p"/teacher/tests/#{@test.id}/edit"} class="btn btn-ghost">
                    <.icon name="hero-pencil" class="w-4 h-4" />
                  </.link>
                <% "published" -> %>
                  <button
                    phx-click="archive"
                    class="btn btn-warning"
                    data-confirm="Archive this test? It won't be available to students anymore."
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
                <p class="text-sm text-secondary">Steps</p>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 text-center">
                <p class="text-3xl font-bold text-base-content">
                  <%= if @test.time_limit_seconds do %>
                    {format_time_short(@test.time_limit_seconds)}
                  <% else %>
                    ∞
                  <% end %>
                </p>
                <p class="text-sm text-secondary">Time Limit</p>
              </div>
              <div class="card bg-base-100 border border-base-300 p-4 text-center">
                <p class="text-3xl font-bold text-base-content">
                  <%= if @test.max_attempts do %>
                    {@test.max_attempts}
                  <% else %>
                    ∞
                  <% end %>
                </p>
                <p class="text-sm text-secondary">Max Attempts</p>
              </div>
            </div>

            <%!-- Steps Preview --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <div class="flex justify-between items-center mb-4">
                  <h2 class="card-title text-base-content">Test Steps</h2>
                  <%= if @test.setup_state == "in_progress" do %>
                    <.link
                      navigate={~p"/teacher/tests/#{@test.id}/edit"}
                      class="btn btn-primary btn-sm"
                    >
                      <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add Steps
                    </.link>
                  <% end %>
                </div>

                <%= if @step_count == 0 do %>
                  <div class="text-center py-8 text-secondary">
                    <.icon
                      name="hero-clipboard-document-list"
                      class="w-12 h-12 mx-auto mb-3 opacity-50"
                    />
                    <p>No steps yet.</p>
                    <%= if @test.setup_state == "in_progress" do %>
                      <.link
                        navigate={~p"/teacher/tests/#{@test.id}/edit"}
                        class="btn btn-primary btn-sm mt-4"
                      >
                        Add Your First Step
                      </.link>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-secondary">
                    This test has {@step_count} step{if @step_count != 1, do: "s"}.
                  </p>
                  <%= if @test.setup_state == "in_progress" do %>
                    <.link
                      navigate={~p"/teacher/tests/#{@test.id}/edit"}
                      class="btn btn-ghost btn-sm mt-4"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> Manage Steps
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
                <h3 class="card-title text-base-content text-base mb-4">Test Status</h3>
                <.state_info state={@test.setup_state} step_count={@step_count} />
              </div>
            </div>

            <%!-- Publishing Info --%>
            <%= if @test.setup_state == "ready" do %>
              <div class="card bg-success/10 border border-success/30">
                <div class="card-body">
                  <h3 class="card-title text-success text-base mb-2">
                    <.icon name="hero-check-circle" class="w-5 h-5" /> Ready to Publish
                  </h3>
                  <p class="text-sm text-base-content mb-4">
                    Your test is complete and ready for students.
                  </p>
                  <button phx-click="publish" class="btn btn-success btn-block">
                    <.icon name="hero-rocket-launch" class="w-4 h-4 mr-2" /> Publish Now
                  </button>
                </div>
              </div>
            <% end %>

            <%!-- Danger Zone --%>
            <%= if @test.setup_state in ["ready", "published"] do %>
              <div class="card bg-error/5 border border-error/20">
                <div class="card-body">
                  <h3 class="card-title text-error text-base">Danger Zone</h3>
                  <p class="text-sm text-secondary mb-4">
                    Archiving removes this test from student access.
                  </p>
                  <button
                    phx-click="archive"
                    data-confirm="Are you sure you want to archive this test?"
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
    <span class="badge badge-info">In Progress</span>
    """
  end

  defp setup_state_badge(%{state: "ready"} = assigns) do
    ~H"""
    <span class="badge badge-warning">Ready</span>
    """
  end

  defp setup_state_badge(%{state: "published"} = assigns) do
    ~H"""
    <span class="badge badge-success">Published</span>
    """
  end

  defp setup_state_badge(%{state: "archived"} = assigns) do
    ~H"""
    <span class="badge badge-ghost">Archived</span>
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
          <p class="font-medium text-base-content">Create Test</p>
          <p class="text-sm text-secondary">✓ Done</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center flex-shrink-0">
          <span class="text-primary font-bold text-sm">2</span>
        </div>
        <div>
          <p class="font-medium text-base-content">Add Steps</p>
          <p class="text-sm text-secondary">Add questions to your test</p>
        </div>
      </div>
      <div class="flex items-start gap-3 opacity-50">
        <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center flex-shrink-0">
          <span class="text-secondary font-bold text-sm">3</span>
        </div>
        <div>
          <p class="font-medium text-base-content">Publish</p>
          <p class="text-sm text-secondary">Make it available to students</p>
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
          <p class="font-medium text-base-content">Create Test</p>
          <p class="text-sm text-secondary">✓ Done</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-success/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-success" />
        </div>
        <div>
          <p class="font-medium text-base-content">Add Steps</p>
          <p class="text-sm text-secondary">✓ {@step_count} steps added</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center flex-shrink-0">
          <span class="text-primary font-bold text-sm">3</span>
        </div>
        <div>
          <p class="font-medium text-base-content">Mark as Ready</p>
          <button phx-click="mark_ready" class="btn btn-primary btn-sm mt-2">
            Mark Ready
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
          <p class="font-medium text-base-content">Create Test</p>
          <p class="text-sm text-secondary">✓ Done</p>
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
        <div class="w-8 h-8 rounded-full bg-warning/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-clock" class="w-4 h-4 text-warning" />
        </div>
        <div>
          <p class="font-medium text-base-content">Publish</p>
          <p class="text-sm text-secondary">Ready to go live!</p>
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
          <p class="font-medium text-base-content">Create Test</p>
          <p class="text-sm text-secondary">✓ Done</p>
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
          <p class="text-sm text-secondary">Live and available</p>
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
          <p class="text-sm text-secondary">Completed</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-check" class="w-4 h-4 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">Published</p>
          <p class="text-sm text-secondary">Was live</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="w-8 h-8 rounded-full bg-error/20 flex items-center justify-center flex-shrink-0">
          <.icon name="hero-archive-box" class="w-4 h-4 text-error" />
        </div>
        <div>
          <p class="font-medium text-base-content">Archived</p>
          <p class="text-sm text-secondary">No longer available</p>
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
