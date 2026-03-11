defmodule MedoruWeb.ClassroomLive.Join do
  @moduledoc """
  LiveView for students to join a classroom using an invite code.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Classrooms

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Join Classroom")
     |> assign(:invite_code, "")
     |> assign(:classroom, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("validate", %{"invite_code" => code}, socket) do
    code = String.upcase(String.trim(code))

    if code == "" do
      {:noreply, assign(socket, invite_code: code, classroom: nil, error: nil)}
    else
      # Look up classroom by invite code
      classroom = Classrooms.get_classroom_by_invite_code(code)

      cond do
        is_nil(classroom) ->
          {:noreply,
           assign(socket, invite_code: code, classroom: nil, error: "Invalid invite code")}

        classroom.status != :active ->
          {:noreply,
           assign(socket,
             invite_code: code,
             classroom: nil,
             error: "This classroom is not accepting new members"
           )}

        true ->
          {:noreply, assign(socket, invite_code: code, classroom: classroom, error: nil)}
      end
    end
  end

  @impl true
  def handle_event("join", %{"invite_code" => code}, socket) do
    user = socket.assigns.current_scope.current_user
    code = String.upcase(String.trim(code))

    case Classrooms.get_classroom_by_invite_code(code) do
      nil ->
        {:noreply, assign(socket, error: "Invalid invite code")}

      classroom ->
        case Classrooms.apply_to_join(classroom.id, user.id) do
          {:ok, _membership} ->
            {:noreply,
             socket
             |> put_flash(:info, "Application submitted! The teacher will review your request.")
             |> push_navigate(to: ~p"/classrooms")}

          {:error, :already_member} ->
            {:noreply, assign(socket, error: "You are already a member of this classroom")}

          {:error, _changeset} ->
            {:noreply, assign(socket, error: "Failed to join classroom. Please try again.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to My Classrooms
          </.link>
          <h1 class="text-3xl font-bold text-base-content">Join Classroom</h1>
          <p class="text-secondary mt-1">Enter an invite code to join a classroom</p>
        </div>

        <%!-- Join Form --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <form phx-change="validate" phx-submit="join" class="space-y-6">
              <%!-- Invite Code Input --%>
              <div class="form-control">
                <label class="label">
                  <span class="label-text text-base-content font-medium">Invite Code</span>
                </label>
                <input
                  type="text"
                  name="invite_code"
                  value={@invite_code}
                  placeholder="Enter code (e.g., ABC12345)"
                  class={[
                    "input input-bordered w-full uppercase tracking-wider font-mono text-lg",
                    @error && "input-error",
                    @classroom && "input-success"
                  ]}
                  maxlength="8"
                  autocomplete="off"
                  phx-debounce="300"
                />
                <%= if @error do %>
                  <label class="label">
                    <span class="label-text-alt text-error">{@error}</span>
                  </label>
                <% end %>
              </div>

              <%!-- Classroom Preview --%>
              <%= if @classroom do %>
                <div class="bg-success/10 border border-success/30 rounded-xl p-4">
                  <h3 class="text-sm font-semibold text-success mb-2">Classroom Found!</h3>
                  <div class="flex items-start gap-3">
                    <div class="w-10 h-10 bg-success/20 rounded-lg flex items-center justify-center">
                      <.icon name="hero-academic-cap" class="w-5 h-5 text-success" />
                    </div>
                    <div>
                      <p class="font-medium text-base-content">{@classroom.name}</p>
                      <p class="text-sm text-secondary line-clamp-2">
                        {@classroom.description || "No description"}
                      </p>
                      <p class="text-sm text-secondary mt-1">
                        <% user = @current_scope.current_user %> Teacher: {display_name(
                          @classroom.teacher,
                          user.id,
                          user.type == "admin"
                        )}
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <%!-- Actions --%>
              <div class="flex items-center gap-4 pt-4 border-t border-base-200">
                <%= if @classroom && is_nil(@error) do %>
                  <button type="submit" class="btn btn-primary">
                    <.icon name="hero-user-plus" class="w-4 h-4 mr-2" /> Apply to Join
                  </button>
                <% else %>
                  <button type="submit" class="btn btn-primary" disabled>
                    <.icon name="hero-magnifying-glass" class="w-4 h-4 mr-2" /> Find Classroom
                  </button>
                <% end %>
                <.link navigate={~p"/classrooms"} class="btn btn-ghost">
                  Cancel
                </.link>
              </div>
            </form>
          </div>
        </div>

        <%!-- Tips --%>
        <div class="mt-8 bg-info/10 rounded-xl p-6 border border-info/20">
          <h3 class="text-sm font-semibold text-info mb-3 flex items-center gap-2">
            <.icon name="hero-light-bulb" class="w-4 h-4" /> How to join a classroom
          </h3>
          <ul class="text-sm text-info/80 space-y-2">
            <li>• Ask your teacher for the classroom invite code</li>
            <li>• Enter the 8-character code above</li>
            <li>• Click Apply to Join to submit your application</li>
            <li>• Wait for the teacher to approve your request</li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
