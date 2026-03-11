defmodule MedoruWeb.Teacher.TestLive.Edit do
  @moduledoc """
  LiveView for editing a teacher test and managing its steps.
  Placeholder for Iteration 15B: Step Builder Framework.
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
       |> put_flash(:error, "You can only edit your own tests.")
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      # Only allow editing in_progress tests
      if test.setup_state != "in_progress" do
        {:ok,
         socket
         |> put_flash(:info, "This test can no longer be edited.")
         |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}
      else
        {:ok,
         socket
         |> assign(:page_title, "Edit #{test.title}")
         |> assign(:test, test)
         |> assign(:step_count, Tests.count_test_steps(test.id))}
      end
    end
  end

  @impl true
  def handle_event("add_step", %{"type" => _step_type}, socket) do
    {:noreply, put_flash(socket, :info, "Step builder coming in Iteration 15B!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/tests/#{@test.id}"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Test
          </.link>

          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-base-content">{@test.title}</h1>
              <p class="text-secondary mt-1">Add steps to your test</p>
            </div>
            <span class="badge badge-info">In Progress</span>
          </div>
        </div>

        <div class="card bg-base-100 border border-base-300 shadow-sm p-12 text-center">
          <.icon name="hero-wrench-screwdriver" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h2 class="text-xl font-semibold text-base-content mb-2">Step Builder Coming Soon</h2>
          <p class="text-secondary max-w-md mx-auto mb-6">
            The step builder interface will be implemented in <strong>Iteration 15B: Step Builder Framework</strong>.
          </p>
          <div class="flex justify-center gap-3">
            <.link navigate={~p"/teacher/tests/#{@test.id}"} class="btn btn-ghost">
              Back to Test
            </.link>
          </div>
        </div>

        <div class="mt-8 card bg-base-100 border border-base-300">
          <div class="card-body">
            <h3 class="card-title text-base">Current Steps</h3>
            <p class="text-secondary">{@step_count} steps added.</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
