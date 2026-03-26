defmodule MedoruWeb.Admin.ClassroomLive.Show do
  @moduledoc """
  Admin view for inspecting a specific classroom.
  Shows all details including invite code, members, and activity.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/admin/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Classrooms")}
          </.link>

          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold text-base-content">{@classroom.name}</h1>
                <span class={["badge", status_badge_color(@classroom.status)]}>
                  {String.capitalize(to_string(@classroom.status))}
                </span>
              </div>
              <p class="text-secondary max-w-2xl">
                {@classroom.description || gettext("No description")}
              </p>
            </div>

            <%= if @classroom.status == :archived do %>
              <button
                phx-click="delete_classroom"
                data-confirm={
                  gettext("Permanently delete this classroom? This action cannot be undone.")
                }
                class="btn btn-error"
              >
                <.icon name="hero-trash" class="w-4 h-4 mr-2" /> {gettext("Delete Permanently")}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-blue-100/80 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400">
              <.icon name="hero-users" class="w-6 h-6" />
            </div>
            <div>
              <p class="text-2xl font-bold text-base-content">{@stats.total_members}</p>
              <p class="text-sm text-secondary">{gettext("Members")}</p>
            </div>
          </div>

          <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-amber-100/80 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400">
              <.icon name="hero-clock" class="w-6 h-6" />
            </div>
            <div>
              <p class="text-2xl font-bold text-base-content">{@stats.pending_applications}</p>
              <p class="text-sm text-secondary">{gettext("Pending")}</p>
            </div>
          </div>

          <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-purple-100/80 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400">
              <.icon name="hero-trophy" class="w-6 h-6" />
            </div>
            <div>
              <p class="text-2xl font-bold text-base-content">{@stats.total_points}</p>
              <p class="text-sm text-secondary">{gettext("Total Points")}</p>
            </div>
          </div>

          <div class="card bg-base-100 border border-base-300 shadow-sm p-4 flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-base-200 text-secondary">
              <.icon name="hero-calendar" class="w-6 h-6" />
            </div>
            <div>
              <p class="text-2xl font-bold text-base-content">
                {Calendar.strftime(@classroom.inserted_at, "%b %d")}
              </p>
              <p class="text-sm text-secondary">{gettext("Created")}</p>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left Column - Details --%>
          <div class="lg:col-span-1 space-y-6">
            <%!-- Invite Code Card --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-base">{gettext("Invite Code")}</h3>
                <div class="flex items-center gap-4 mt-4">
                  <div class="bg-base-200 px-6 py-3 rounded-xl font-mono text-xl tracking-wider text-base-content flex-1 text-center">
                    {@classroom.invite_code}
                  </div>
                </div>
                <p class="text-sm text-secondary mt-4">
                  {gettext("Students use this code to join the classroom.")}
                </p>
              </div>
            </div>

            <%!-- Teacher Info --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-base">{gettext("Teacher")}</h3>
                <%= if @classroom.teacher do %>
                  <div class="flex items-center gap-3 mt-4">
                    <% avatar_src =
                      (@classroom.teacher.profile && @classroom.teacher.profile.avatar) ||
                        @classroom.teacher.avatar_url %>
                    <%= if avatar_src do %>
                      <div class="avatar">
                        <div class="w-12 h-12 rounded-full">
                          <img src={avatar_src} alt="" class="object-cover" />
                        </div>
                      </div>
                    <% else %>
                      <div class="avatar placeholder">
                        <div class="bg-primary text-primary-content rounded-full w-12 h-12 flex items-center justify-center">
                          {String.first(@classroom.teacher.name || @classroom.teacher.email)
                          |> String.upcase()}
                        </div>
                      </div>
                    <% end %>
                    <div>
                      <p class="font-medium text-base-content">
                        {@classroom.teacher.name || gettext("No name")}
                      </p>
                      <p class="text-sm text-secondary">{@classroom.teacher.email}</p>
                    </div>
                  </div>
                <% else %>
                  <p class="text-secondary">{gettext("Teacher account no longer exists")}</p>
                <% end %>
              </div>
            </div>

            <%!-- Details Card --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-base">{gettext("Details")}</h3>
                <div class="space-y-3 mt-4 text-sm">
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Slug")}</span>
                    <span class="font-mono">{@classroom.slug}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("ID")}</span>
                    <span class="font-mono text-xs">{@classroom.id}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Created")}</span>
                    <span>{Calendar.strftime(@classroom.inserted_at, "%Y-%m-%d %H:%M")}</span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-secondary">{gettext("Updated")}</span>
                    <span>{Calendar.strftime(@classroom.updated_at, "%Y-%m-%d %H:%M")}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Right Column - Members --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Pending Applications --%>
            <%= if @pending_memberships != [] do %>
              <div class="card bg-warning/10 border border-warning/30">
                <div class="card-body">
                  <h3 class="card-title text-warning flex items-center gap-2 text-base">
                    <.icon name="hero-clock" class="w-5 h-5" />
                    {gettext("Pending Applications")} ({length(@pending_memberships)})
                  </h3>
                  <div class="space-y-3 mt-4">
                    <%= for membership <- @pending_memberships do %>
                      <div class="flex items-center justify-between bg-base-100 rounded-xl p-4 border border-base-300">
                        <div class="flex items-center gap-3">
                          <% avatar_src =
                            (membership.user.profile && membership.user.profile.avatar) ||
                              membership.user.avatar_url %>
                          <%= if avatar_src do %>
                            <div class="avatar">
                              <div class="w-10 h-10 rounded-full">
                                <img src={avatar_src} alt="" class="object-cover" />
                              </div>
                            </div>
                          <% else %>
                            <div class="avatar placeholder">
                              <div class="bg-primary text-primary-content rounded-full w-10 h-10 flex items-center justify-center">
                                {String.first(membership.user.name || membership.user.email)
                                |> String.upcase()}
                              </div>
                            </div>
                          <% end %>
                          <div>
                            <p class="font-medium text-base-content">
                              {membership.user.name || gettext("No name")}
                            </p>
                            <p class="text-sm text-secondary">{membership.user.email}</p>
                          </div>
                        </div>
                        <div class="flex items-center gap-2">
                          <button
                            phx-click="reject_member"
                            phx-value-id={membership.id}
                            class="btn btn-ghost btn-sm"
                          >
                            {gettext("Reject")}
                          </button>
                          <button
                            phx-click="approve_member"
                            phx-value-id={membership.id}
                            class="btn btn-success btn-sm"
                          >
                            {gettext("Approve")}
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Approved Members --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <div class="flex justify-between items-center mb-4">
                  <h3 class="card-title text-base">{gettext("Classroom Members")}</h3>
                  <span class="badge badge-ghost">{length(@members)} {gettext("members")}</span>
                </div>

                <%= if @members == [] do %>
                  <div class="text-center py-8 text-secondary">
                    <.icon name="hero-users" class="w-12 h-12 text-secondary/30 mx-auto mb-3" />
                    <p>{gettext("No members yet.")}</p>
                  </div>
                <% else %>
                  <div class="space-y-2">
                    <%= for membership <- @members do %>
                      <div class="flex items-center justify-between p-4 hover:bg-base-200/50 rounded-xl transition-colors">
                        <div class="flex items-center gap-3">
                          <% avatar_src =
                            (membership.user.profile && membership.user.profile.avatar) ||
                              membership.user.avatar_url %>
                          <%= if avatar_src do %>
                            <div class="avatar">
                              <div class="w-10 h-10 rounded-full">
                                <img src={avatar_src} alt="" class="object-cover" />
                              </div>
                            </div>
                          <% else %>
                            <div class="avatar placeholder">
                              <div class="bg-primary text-primary-content rounded-full w-10 h-10 flex items-center justify-center">
                                {String.first(membership.user.name || membership.user.email)
                                |> String.upcase()}
                              </div>
                            </div>
                          <% end %>
                          <div>
                            <p class="font-medium text-base-content">
                              {membership.user.name || gettext("No name")}
                            </p>
                            <p class="text-sm text-secondary">
                              {membership.user.email} • {gettext("Joined")} {Calendar.strftime(
                                membership.joined_at || membership.inserted_at,
                                "%b %d, %Y"
                              )}
                            </p>
                          </div>
                        </div>
                        <div class="flex items-center gap-4">
                          <div class="text-right">
                            <p class="font-semibold text-base-content">{membership.points} pts</p>
                            <p class="text-xs text-secondary capitalize">{membership.role}</p>
                          </div>
                          <button
                            phx-click="remove_member"
                            phx-value-id={membership.id}
                            data-confirm={gettext("Remove this student?")}
                            class="btn btn-ghost btn-sm text-error hover:bg-error/10"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    classroom = Classrooms.get_classroom!(id)
    stats = Classrooms.get_classroom_stats(classroom.id)
    members = Classrooms.list_classroom_members(classroom.id)
    pending = Classrooms.list_pending_memberships(classroom.id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Admin - %{name}", name: classroom.name))
     |> assign(:classroom, classroom)
     |> assign(:stats, stats)
     |> assign(:members, members)
     |> assign(:pending_memberships, pending)}
  end

  @impl true
  def handle_event("approve_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.approve_membership(membership) do
      {:ok, _} ->
        pending = Classrooms.list_pending_memberships(socket.assigns.classroom.id)
        members = Classrooms.list_classroom_members(socket.assigns.classroom.id)
        stats = Classrooms.get_classroom_stats(socket.assigns.classroom.id)

        {:noreply,
         socket
         |> assign(:pending_memberships, pending)
         |> assign(:members, members)
         |> assign(:stats, stats)
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
        pending = Classrooms.list_pending_memberships(socket.assigns.classroom.id)
        stats = Classrooms.get_classroom_stats(socket.assigns.classroom.id)

        {:noreply,
         socket
         |> assign(:pending_memberships, pending)
         |> assign(:stats, stats)
         |> put_flash(:info, gettext("Application rejected."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reject application."))}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => membership_id}, socket) do
    membership = Classrooms.get_membership!(membership_id)

    case Classrooms.remove_member(membership) do
      {:ok, _} ->
        members = Classrooms.list_classroom_members(socket.assigns.classroom.id)
        stats = Classrooms.get_classroom_stats(socket.assigns.classroom.id)

        {:noreply,
         socket
         |> assign(:members, members)
         |> assign(:stats, stats)
         |> put_flash(:info, gettext("Student removed from classroom."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove student."))}
    end
  end

  @impl true
  def handle_event("delete_classroom", _, socket) do
    classroom = socket.assigns.classroom

    case Classrooms.delete_classroom(classroom) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Classroom deleted permanently."))
         |> push_navigate(to: ~p"/admin/classrooms")}

      {:error, :not_archived} ->
        {:noreply, put_flash(socket, :error, gettext("Only archived classrooms can be deleted."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete classroom."))}
    end
  end

  def status_badge_color(:active), do: "badge-success"
  def status_badge_color(:closed), do: "badge-warning"
  def status_badge_color(:archived), do: "badge-neutral"
  def status_badge_color(_), do: "badge-ghost"
end
