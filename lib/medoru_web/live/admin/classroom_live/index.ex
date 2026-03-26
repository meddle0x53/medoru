defmodule MedoruWeb.Admin.ClassroomLive.Index do
  @moduledoc """
  Admin interface for listing and managing all classrooms.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Classroom Management")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("Manage all classrooms across the platform. Total: %{count}",
              count: @total_count
            )}
          </p>
        </div>

        <%!-- Filters --%>
        <div class="card bg-base-100 shadow-sm border border-base-300 mb-6">
          <div class="card-body">
            <div class="flex flex-col sm:flex-row sm:items-center gap-2">
              <span class="text-sm font-medium text-base-content/70 shrink-0">
                {gettext("Filter by status:")}
              </span>
              <div class="join join-horizontal flex-wrap">
                <button
                  phx-click="filter_status"
                  phx-value-status=""
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(is_nil(@status_filter), do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("All")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="active"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "active", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Active")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="closed"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "closed", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Closed")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="archived"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "archived", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Archived")}
                </button>
              </div>
              <%= if @status_filter do %>
                <button type="button" phx-click="clear_filters" class="btn btn-sm btn-ghost">
                  {gettext("Clear")}
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Classrooms Table (Desktop) / Cards (Mobile) --%>
        <div class="card bg-base-100 shadow-sm border border-base-300">
          <%!-- Desktop Table --%>
          <div class="hidden md:block table-responsive">
            <table class="table table-zebra w-full">
              <thead>
                <tr class="bg-base-200/50">
                  <th class="text-base-content/70">{gettext("Classroom")}</th>
                  <th class="text-base-content/70">{gettext("Teacher")}</th>
                  <th class="text-base-content/70">{gettext("Status")}</th>
                  <th class="text-base-content/70">{gettext("Invite Code")}</th>
                  <th class="text-base-content/70">{gettext("Created")}</th>
                  <th class="text-base-content/70 text-right">{gettext("Actions")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for classroom <- @classrooms do %>
                  <tr class="hover:bg-base-200/50">
                    <td>
                      <div class="flex items-center gap-3">
                        <div class="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                          <.icon name="hero-academic-cap" class="w-5 h-5 text-primary" />
                        </div>
                        <div>
                          <div class="font-medium text-base-content">{classroom.name}</div>
                          <div class="text-sm text-base-content/60">{classroom.slug}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div class="flex items-center gap-2">
                        <%= if classroom.teacher do %>
                          <% avatar_src =
                            (classroom.teacher.profile && classroom.teacher.profile.avatar) ||
                              classroom.teacher.avatar_url %>
                          <%= if avatar_src do %>
                            <div class="avatar">
                              <div class="w-6 h-6 rounded-full">
                                <img src={avatar_src} alt="" class="object-cover" />
                              </div>
                            </div>
                          <% else %>
                            <div class="avatar placeholder">
                              <div class="bg-primary text-primary-content rounded-full w-6 h-6 flex items-center justify-center text-xs">
                                {String.first(classroom.teacher.name || classroom.teacher.email)
                                |> String.upcase()}
                              </div>
                            </div>
                          <% end %>
                          <span class="text-sm">
                            {classroom.teacher.name || classroom.teacher.email}
                          </span>
                        <% else %>
                          <span class="text-sm text-base-content/50">{gettext("Unknown")}</span>
                        <% end %>
                      </div>
                    </td>
                    <td>
                      <span class={["badge", status_badge_color(classroom.status)]}>
                        {String.capitalize(to_string(classroom.status))}
                      </span>
                    </td>
                    <td>
                      <code class="bg-base-200 px-2 py-1 rounded text-sm font-mono">
                        {classroom.invite_code}
                      </code>
                    </td>
                    <td class="text-base-content/70">
                      {Calendar.strftime(classroom.inserted_at, "%b %d, %Y")}
                    </td>
                    <td class="text-right">
                      <.link
                        navigate={~p"/admin/classrooms/#{classroom.id}"}
                        class="btn btn-sm btn-ghost"
                      >
                        <.icon name="hero-eye" class="w-4 h-4" /> {gettext("View")}
                      </.link>
                      <%= if classroom.status == :archived do %>
                        <button
                          phx-click="delete_classroom"
                          phx-value-id={classroom.id}
                          data-confirm={
                            gettext(
                              "Permanently delete this classroom? This action cannot be undone."
                            )
                          }
                          class="btn btn-sm btn-ghost text-error"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" /> {gettext("Delete")}
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Mobile Cards --%>
          <div class="md:hidden divide-y divide-base-200">
            <%= for classroom <- @classrooms do %>
              <div class="p-4 hover:bg-base-200/50">
                <div class="flex items-start gap-3">
                  <div class="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center flex-shrink-0">
                    <.icon name="hero-academic-cap" class="w-5 h-5 text-primary" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <span class="font-medium text-base-content">{classroom.name}</span>
                      <span class={["badge badge-sm", status_badge_color(classroom.status)]}>
                        {String.capitalize(to_string(classroom.status))}
                      </span>
                    </div>
                    <div class="text-sm text-base-content/60 truncate">
                      {(classroom.teacher && (classroom.teacher.name || classroom.teacher.email)) ||
                        gettext("Unknown")}
                    </div>
                    <div class="flex items-center gap-3 mt-2 text-sm">
                      <code class="bg-base-200 px-2 py-0.5 rounded font-mono text-xs">
                        {classroom.invite_code}
                      </code>
                      <span class="text-secondary">
                        {Calendar.strftime(classroom.inserted_at, "%b %d, %Y")}
                      </span>
                    </div>
                  </div>
                  <div class="flex-shrink-0 flex flex-col gap-1">
                    <.link
                      navigate={~p"/admin/classrooms/#{classroom.id}"}
                      class="btn btn-ghost btn-xs"
                      title={gettext("View")}
                    >
                      <.icon name="hero-eye" class="w-4 h-4" />
                    </.link>
                    <%= if classroom.status == :archived do %>
                      <button
                        phx-click="delete_classroom"
                        phx-value-id={classroom.id}
                        data-confirm={gettext("Permanently delete?")}
                        class="btn btn-ghost btn-xs text-error"
                        title={gettext("Delete")}
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @classrooms == [] do %>
            <div class="p-12 text-center">
              <.icon name="hero-academic-cap" class="w-12 h-12 text-base-content/30 mx-auto mb-4" />
              <p class="text-base-content/50">
                {gettext("No classrooms found matching your criteria.")}
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status_filter = params["status"]
    teacher_id = params["teacher_id"]

    opts =
      []
      |> then(&if status_filter, do: [{:status, String.to_atom(status_filter)} | &1], else: &1)
      |> then(&if teacher_id, do: [{:teacher_id, teacher_id} | &1], else: &1)

    classrooms = Classrooms.list_all_classrooms(opts)

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Classrooms"))
     |> assign(:classrooms, classrooms)
     |> assign(:status_filter, status_filter)
     |> assign(:total_count, length(classrooms))}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_param = if status in ["active", "closed", "archived"], do: status, else: nil

    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/classrooms?#{%{status: status_param}}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/classrooms")}
  end

  @impl true
  def handle_event("delete_classroom", %{"id" => id}, socket) do
    classroom = Classrooms.get_classroom!(id)

    case Classrooms.delete_classroom(classroom) do
      {:ok, _} ->
        opts =
          []
          |> then(
            &if socket.assigns.status_filter,
              do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
              else: &1
          )

        classrooms = Classrooms.list_all_classrooms(opts)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Classroom deleted permanently."))
         |> assign(:classrooms, classrooms)}

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
