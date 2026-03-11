defmodule MedoruWeb.ClassroomLive.Index do
  @moduledoc """
  LiveView for all users to view their classrooms.
  Shows owned classrooms (for teachers) and joined classrooms (for students).
  Includes inline join functionality.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.Components.Helpers, only: [format_relative_time: 1]

  alias Medoru.Classrooms

  @per_page 12

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    {:ok,
     socket
     |> assign(:page_title, "My Classrooms")
     |> assign(:user, user)
     |> assign(:invite_code, "")
     |> assign(:join_error, nil)
     |> assign(:join_success, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_scope.current_user
    page = parse_page(params["page"])

    # Get owned classrooms (for teachers/admins)
    owned_classrooms =
      if user.type in ["teacher", "admin"] do
        Classrooms.list_teacher_classrooms(user.id)
      else
        []
      end

    # Get joined classrooms (as student)
    joined_classrooms = Classrooms.list_student_classrooms(user.id)

    # Get pending applications
    pending_applications = list_pending_applications(user.id)

    # Combine and paginate
    all_classrooms = owned_classrooms ++ joined_classrooms

    # Sort by inserted_at desc
    sorted_classrooms =
      all_classrooms
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.uniq_by(& &1.id)

    total_count = length(sorted_classrooms)
    total_pages = max(1, ceil(total_count / @per_page))
    paginated_classrooms = paginate(sorted_classrooms, page, @per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:owned_count, length(owned_classrooms))
     |> assign(:joined_count, length(joined_classrooms))
     |> assign(:classrooms, paginated_classrooms)
     |> assign(:pending_applications, pending_applications)}
  end

  @impl true
  def handle_event("validate_code", %{"invite_code" => code}, socket) do
    code = String.upcase(String.trim(code))

    if code == "" do
      {:noreply, assign(socket, invite_code: code, join_error: nil)}
    else
      classroom = Classrooms.get_classroom_by_invite_code(code)

      cond do
        is_nil(classroom) ->
          {:noreply, assign(socket, invite_code: code, join_error: "Invalid invite code")}

        classroom.status != :active ->
          {:noreply, assign(socket, invite_code: code, join_error: "This classroom is not accepting new members")}

        Classrooms.is_member?(classroom.id, socket.assigns.user.id) ->
          {:noreply, assign(socket, invite_code: code, join_error: "You are already a member of this classroom")}

        true ->
          {:noreply, assign(socket, invite_code: code, join_error: nil, classroom_preview: classroom)}
      end
    end
  end

  @impl true
  def handle_event("join", %{"invite_code" => code}, socket) do
    user = socket.assigns.user
    code = String.upcase(String.trim(code))

    case Classrooms.get_classroom_by_invite_code(code) do
      nil ->
        {:noreply, assign(socket, join_error: "Invalid invite code")}

      classroom ->
        case Classrooms.apply_to_join(classroom.id, user.id) do
          {:ok, _membership} ->
            {:noreply,
             socket
             |> put_flash(:info, "Application submitted! The teacher will review your request.")
             |> push_patch(to: ~p"/classrooms")}

          {:error, :already_member} ->
            {:noreply, assign(socket, join_error: "You are already a member of this classroom")}

          {:error, _changeset} ->
            {:noreply, assign(socket, join_error: "Failed to join classroom. Please try again.")}
        end
    end
  end

  @impl true
  def handle_event("cancel_application", %{"id" => membership_id}, socket) do
    # Get the membership and delete it if it's still pending
    case Medoru.Repo.get(Medoru.Classrooms.ClassroomMembership, membership_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Application not found.")}

      membership ->
        if membership.user_id == socket.assigns.user.id && membership.status == :pending do
          Medoru.Repo.delete(membership)
          {:noreply, push_patch(socket, to: ~p"/classrooms")}
        else
          {:noreply, put_flash(socket, :error, "Cannot cancel this application.")}
        end
    end
  end

  defp list_pending_applications(user_id) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Classrooms.ClassroomMembership

    ClassroomMembership
    |> where([m], m.user_id == ^user_id and m.status == :pending)
    |> preload(:classroom)
    |> Repo.all()
  end

  defp paginate(list, page, per_page) do
    list
    |> Enum.drop((page - 1) * per_page)
    |> Enum.take(per_page)
  end

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page), do: String.to_integer(page)
  defp parse_page(page) when is_integer(page), do: max(1, page)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">My Classrooms</h1>
          <p class="text-secondary mt-1">
            <%= if @user.type in ["teacher", "admin"] do %>
              Manage your classrooms and memberships
            <% else %>
              Join classrooms to learn with others
            <% end %>
          </p>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <%= if @user.type in ["teacher", "admin"] do %>
            <.stat_card 
              icon="hero-building-office" 
              label="Owned" 
              value={@owned_count} 
              color="primary" 
            />
          <% end %>
          <.stat_card 
            icon="hero-users" 
            label="Joined" 
            value={@joined_count} 
            color="success" 
          />
          <.stat_card 
            icon="hero-clock" 
            label="Pending" 
            value={length(@pending_applications)} 
            color="warning" 
          />
        </div>

        <%!-- Pending Applications Section --%>
        <%= if @pending_applications != [] do %>
          <div class="card bg-warning/10 border border-warning/30 mb-8">
            <div class="card-body">
              <h2 class="card-title text-warning">
                <.icon name="hero-clock" class="w-5 h-5" />
                Pending Applications ({length(@pending_applications)})
              </h2>
              <div class="space-y-3 mt-4">
                <%= for membership <- @pending_applications do %>
                  <div class="flex items-center justify-between bg-base-100 rounded-xl p-4 border border-base-300">
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                        <.icon name="hero-academic-cap" class="w-5 h-5 text-primary" />
                      </div>
                      <div>
                        <p class="font-medium text-base-content">{membership.classroom.name}</p>
                        <p class="text-sm text-secondary">
                          Applied {format_relative_time(membership.inserted_at)}
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2">
                      <span class="badge badge-warning">Pending</span>
                      <button
                        phx-click="cancel_application"
                        phx-value-id={membership.id}
                        data-confirm="Cancel this application?"
                        class="btn btn-ghost btn-sm text-error"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Join Classroom Form --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm mb-8">
          <div class="card-body">
            <h3 class="card-title text-base-content mb-4">Join a Classroom</h3>
            <form phx-change="validate_code" phx-submit="join" class="flex flex-col sm:flex-row gap-4">
              <div class="flex-1">
                <input
                  type="text"
                  name="invite_code"
                  value={@invite_code}
                  placeholder="Enter invite code (e.g., ABC12345)"
                  class={[
                    "input input-bordered w-full uppercase tracking-wider font-mono",
                    @join_error && "input-error",
                    assigns[:classroom_preview] && "input-success"
                  ]}
                  maxlength="8"
                  autocomplete="off"
                  phx-debounce="300"
                />
                <%= if @join_error do %>
                  <p class="text-error text-sm mt-1">{@join_error}</p>
                <% end %>
              </div>
              <button
                type="submit"
                class="btn btn-primary"
                disabled={@invite_code == "" || not is_nil(@join_error)}
              >
                <.icon name="hero-user-plus" class="w-4 h-4 mr-2" />
                Apply to Join
              </button>
            </form>

            <%!-- Classroom Preview --%>
            <%= if assigns[:classroom_preview] && is_nil(@join_error) do %>
              <div class="mt-4 bg-success/10 border border-success/30 rounded-xl p-4">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 bg-success/20 rounded-lg flex items-center justify-center">
                    <.icon name="hero-check" class="w-5 h-5 text-success" />
                  </div>
                  <div>
                    <p class="font-medium text-base-content">{assigns.classroom_preview.name}</p>
                    <p class="text-sm text-secondary">
                      Teacher: {assigns.classroom_preview.teacher.name || assigns.classroom_preview.teacher.email}
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Create Classroom Button (for teachers/admins) --%>
        <%= if @user.type in ["teacher", "admin"] do %>
          <div class="flex justify-end mb-6">
            <.link navigate={~p"/teacher/classrooms/new"}>
              <button class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4 mr-2" />
                Create Classroom
              </button>
            </.link>
          </div>
        <% end %>

        <%!-- Classrooms Grid --%>
        <%= if @classrooms == [] do %>
          <div class="text-center py-16 bg-base-100 rounded-xl border border-base-300 border-dashed">
            <.icon name="hero-academic-cap" class="w-16 h-16 text-secondary/30 mx-auto mb-4" />
            <h3 class="text-xl font-semibold text-base-content mb-2">No classrooms yet</h3>
            <p class="text-secondary mb-6">
              <%= if @user.type in ["teacher", "admin"] do %>
                Create your first classroom or join one with an invite code above
              <% else %>
                Join a classroom using an invite code above to start learning
              <% end %>
            </p>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for classroom <- @classrooms do %>
              <.classroom_card classroom={classroom} user={@user} />
            <% end %>
          </div>

          <%!-- Pagination --%>
          <%= if @total_pages > 1 do %>
            <.pagination page={@page} total_pages={@total_pages} />
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, required: true

  defp stat_card(%{color: "primary"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 p-4 flex items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-primary/10 text-primary">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  defp stat_card(%{color: "success"} = assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 p-4 flex items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-success/10 text-success">
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
    <div class="card bg-base-100 border border-base-300 p-4 flex items-center gap-4">
      <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-warning/10 text-warning">
        <.icon name={@icon} class="w-6 h-6" />
      </div>
      <div>
        <p class="text-2xl font-bold text-base-content">{@value}</p>
        <p class="text-sm text-secondary">{@label}</p>
      </div>
    </div>
    """
  end

  attr :classroom, :map, required: true
  attr :user, :map, required: true

  defp classroom_card(assigns) do
    is_owner = assigns.classroom.teacher_id == assigns.user.id

    assigns = assign(assigns, :is_owner, is_owner)

    ~H"""
    <div class={[
      "card border shadow-sm hover:shadow-md transition-all duration-200",
      @is_owner && "bg-primary/5 border-primary/30",
      !@is_owner && "bg-base-100 border-base-300 hover:border-primary/30"
    ]}>
      <div class="card-body">
        <div class="flex items-start justify-between mb-3">
          <div class={[
            "w-12 h-12 rounded-xl flex items-center justify-center",
            @is_owner && "bg-primary/20",
            !@is_owner && "bg-primary/10"
          ]}>
            <.icon name="hero-academic-cap" class="w-6 h-6 text-primary" />
          </div>
          <%= if @is_owner do %>
            <span class="badge badge-primary">Owner</span>
          <% else %>
            <span class="badge badge-success">Member</span>
          <% end %>
        </div>

        <h3 class="text-lg font-semibold text-base-content mb-1">{@classroom.name}</h3>
        <p class="text-sm text-secondary mb-4 line-clamp-2">
          {@classroom.description || "No description"}
        </p>

        <div class="text-sm text-secondary mb-4">
          <div class="flex items-center gap-1.5 mb-1">
            <.icon name="hero-user" class="w-4 h-4" />
            <span>Teacher: {@classroom.teacher.name || @classroom.teacher.email}</span>
          </div>
          <div class="flex items-center gap-1.5">
            <.icon name="hero-calendar" class="w-4 h-4" />
            <span>Created {Calendar.strftime(@classroom.inserted_at, "%b %d, %Y")}</span>
          </div>
        </div>

        <div class="card-actions justify-end pt-4 border-t border-base-200">
          <%= if @is_owner do %>
            <.link navigate={~p"/teacher/classrooms/#{@classroom.id}"} class="btn btn-primary btn-sm">
              Manage →
            </.link>
          <% else %>
            <.link navigate={~p"/classrooms/#{@classroom.id}"} class="btn btn-ghost btn-sm text-primary">
              View →
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true

  defp pagination(assigns) do
    ~H"""
    <div class="mt-8 flex justify-center">
      <div class="flex items-center gap-2">
        <%= if @page > 1 do %>
          <.link patch={~p"/classrooms?page=#{@page - 1}"} class="btn btn-ghost btn-sm">
            ← Prev
          </.link>
        <% else %>
          <span class="btn btn-ghost btn-sm opacity-50" disabled>← Prev</span>
        <% end %>

        <span class="px-4 py-2 bg-base-200 rounded-lg text-base-content">
          Page {@page} of {@total_pages}
        </span>

        <%= if @page < @total_pages do %>
          <.link patch={~p"/classrooms?page=#{@page + 1}"} class="btn btn-ghost btn-sm">
            Next →
          </.link>
        <% else %>
          <span class="btn btn-ghost btn-sm opacity-50" disabled>Next →</span>
        <% end %>
      </div>
    </div>
    """
  end
end
