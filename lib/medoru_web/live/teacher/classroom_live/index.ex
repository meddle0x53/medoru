defmodule MedoruWeb.Teacher.ClassroomLive.Index do
  @moduledoc """
  LiveView for teachers to manage their classrooms.
  Shows a list of all classrooms with quick actions.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classrooms = Classrooms.list_teacher_classrooms(user.id)

    # Pre-fetch stats for all classrooms in a single batch query
    classroom_ids = Enum.map(classrooms, & &1.id)
    stats_map = Classrooms.get_classroom_stats_batch(classroom_ids)

    {:ok,
     socket
     |> assign(:page_title, gettext("My Classrooms"))
     |> assign(:classrooms, classrooms)
     |> assign(:stats_map, stats_map)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex justify-between items-center mb-8">
          <div>
            <h1 class="text-3xl font-bold text-base-content">{gettext("My Classrooms")}</h1>
            <p class="text-secondary mt-1">{gettext("Manage your classrooms and students")}</p>
          </div>
          <.link navigate={~p"/teacher/classrooms/new"}>
            <button class="btn btn-primary">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Create Classroom")}
            </button>
          </.link>
        </div>

        <%!-- Empty State --%>
        <%= if @classrooms == [] do %>
          <div class="text-center py-16 bg-base-100 rounded-xl border border-base-300 border-dashed">
            <.icon name="hero-academic-cap" class="w-16 h-16 text-secondary/30 mx-auto mb-4" />
            <h3 class="text-xl font-semibold text-base-content mb-2">
              {gettext("No classrooms yet")}
            </h3>
            <p class="text-secondary mb-6">
              {gettext("Create your first classroom to start teaching")}
            </p>
            <.link navigate={~p"/teacher/classrooms/new"}>
              <button class="btn btn-primary">
                <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Create Classroom")}
              </button>
            </.link>
          </div>
        <% else %>
          <%!-- Classrooms Grid --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for classroom <- @classrooms do %>
              <.classroom_card classroom={classroom} stats={@stats_map[classroom.id]} />
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp classroom_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm hover:shadow-md hover:border-primary/30 transition-all duration-200">
      <div class="card-body">
        <div class="flex items-start justify-between mb-4">
          <div class="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center">
            <.icon name="hero-academic-cap" class="w-6 h-6 text-primary" />
          </div>
          <.badge status={@classroom.status} />
        </div>

        <h3 class="text-lg font-semibold text-base-content mb-1">{@classroom.name}</h3>
        <p class="text-sm text-secondary mb-4 line-clamp-2">
          {@classroom.description || gettext("No description")}
        </p>

        <div class="flex items-center gap-4 text-sm text-secondary mb-4">
          <div class="flex items-center gap-1.5">
            <.icon name="hero-users" class="w-4 h-4" />
            <span>{@stats.total_members} {gettext("members")}</span>
          </div>
          <div class="flex items-center gap-1.5">
            <.icon name="hero-calendar" class="w-4 h-4" />
            <span>{Calendar.strftime(@classroom.inserted_at, "%b %d, %Y")}</span>
          </div>
        </div>

        <div class="card-actions justify-end pt-4 border-t border-base-200">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}"}
            class="btn btn-ghost btn-sm text-primary"
          >
            {gettext("Manage Classroom")} →
          </.link>
        </div>
      </div>
    </div>
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
end
