defmodule MedoruWeb.Admin.GameLive.Index do
  @moduledoc """
  Admin interface for listing and managing all games.
  """
  use MedoruWeb, :live_view

  alias Medoru.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Game Management")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("Manage all games across the platform. Total: %{count}", count: length(@games))}
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
                  phx-value-status="draft"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "draft", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Draft")}
                </button>
                <button
                  phx-click="filter_status"
                  phx-value-status="published"
                  class={[
                    "join-item btn btn-sm min-w-[40px]",
                    if(@status_filter == "published", do: "btn-active btn-primary", else: "btn-ghost")
                  ]}
                >
                  {gettext("Published")}
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

        <%!-- Games Table --%>
        <div class="card bg-base-100 shadow-sm border border-base-300">
          <div class="hidden md:block table-responsive">
            <table class="table table-zebra w-full">
              <thead>
                <tr class="bg-base-200/50">
                  <th class="text-base-content/70">{gettext("Name")}</th>
                  <th class="text-base-content/70">{gettext("Type")}</th>
                  <th class="text-base-content/70">{gettext("Status")}</th>
                  <th class="text-base-content/70">{gettext("Classroom")}</th>
                  <th class="text-base-content/70">{gettext("Skill")}</th>
                  <th class="text-base-content/70 text-right">{gettext("Actions")}</th>
                </tr>
              </thead>
              <tbody>
                <%= for game <- @games do %>
                  <tr class="hover:bg-base-200/50">
                    <td>
                      <div class="font-medium text-base-content">{game.name}</div>
                    </td>
                    <td>
                      <span class="text-sm text-base-content/60">
                        {String.replace(game.type, "_", " ") |> String.capitalize()}
                      </span>
                    </td>
                    <td>
                      <span class={["badge badge-sm", status_badge_color(game.status)]}>
                        {String.capitalize(to_string(game.status))}
                      </span>
                    </td>
                    <td>
                      <%= if game.classroom do %>
                        <span class="text-sm">{game.classroom.name}</span>
                      <% else %>
                        <span class="text-sm text-base-content/50">{gettext("Unknown")}</span>
                      <% end %>
                    </td>
                    <td>
                      <span class="text-sm">{game.skill_level}</span>
                    </td>
                    <td class="text-right">
                      <%= if game.status != :archived do %>
                        <button
                          phx-click="archive"
                          phx-value-id={game.id}
                          data-confirm={gettext("Archive this game?")}
                          class="btn btn-sm btn-ghost"
                        >
                          <.icon name="hero-archive-box" class="w-4 h-4" /> {gettext("Archive")}
                        </button>
                      <% else %>
                        <button
                          phx-click="unarchive"
                          phx-value-id={game.id}
                          class="btn btn-sm btn-ghost"
                        >
                          <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> {gettext("Restore")}
                        </button>
                      <% end %>
                      <button
                        phx-click="delete"
                        phx-value-id={game.id}
                        data-confirm={gettext("Permanently delete this game? This cannot be undone.")}
                        class="btn btn-sm btn-ghost text-error"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Mobile Cards --%>
          <div class="md:hidden divide-y divide-base-200">
            <%= for game <- @games do %>
              <div class="p-4 hover:bg-base-200/50">
                <div class="flex items-start gap-3">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-1">
                      <span class="font-medium text-base-content">{game.name}</span>
                      <span class={["badge badge-sm", status_badge_color(game.status)]}>
                        {String.capitalize(to_string(game.status))}
                      </span>
                    </div>
                    <div class="text-sm text-base-content/60">
                      {String.replace(game.type, "_", " ") |> String.capitalize()}
                      <%= if game.classroom do %>
                        • {game.classroom.name}
                      <% end %>
                    </div>
                  </div>
                  <div class="flex-shrink-0 flex flex-col gap-1">
                    <%= if game.status != :archived do %>
                      <button
                        phx-click="archive"
                        phx-value-id={game.id}
                        data-confirm={gettext("Archive?")}
                        class="btn btn-ghost btn-xs"
                        title={gettext("Archive")}
                      >
                        <.icon name="hero-archive-box" class="w-4 h-4" />
                      </button>
                    <% else %>
                      <button
                        phx-click="unarchive"
                        phx-value-id={game.id}
                        class="btn btn-ghost btn-xs"
                        title={gettext("Restore")}
                      >
                        <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
                      </button>
                    <% end %>
                    <button
                      phx-click="delete"
                      phx-value-id={game.id}
                      data-confirm={gettext("Delete?")}
                      class="btn btn-ghost btn-xs text-error"
                      title={gettext("Delete")}
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @games == [] do %>
            <div class="p-12 text-center">
              <.icon name="hero-puzzle-piece" class="w-12 h-12 text-base-content/30 mx-auto mb-4" />
              <p class="text-base-content/50">{gettext("No games found matching your criteria.")}</p>
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

    opts =
      []
      |> then(&if status_filter, do: [{:status, String.to_atom(status_filter)} | &1], else: &1)

    games = Games.list_all_games(opts)

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Games"))
     |> assign(:games, games)
     |> assign(:status_filter, status_filter)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_param = if status in ["draft", "published", "archived"], do: status, else: nil

    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/games?#{%{status: status_param}}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/games")}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    game = Games.get_game!(id)
    {:ok, _} = Games.archive_game(game)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    games = Games.list_all_games(opts)

    {:noreply,
     socket
     |> assign(:games, games)
     |> put_flash(:info, gettext("Game archived."))}
  end

  @impl true
  def handle_event("unarchive", %{"id" => id}, socket) do
    game = Games.get_game!(id)
    {:ok, _} = Games.unarchive_game(game)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    games = Games.list_all_games(opts)

    {:noreply,
     socket
     |> assign(:games, games)
     |> put_flash(:info, gettext("Game restored to published."))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    game = Games.get_game!(id)
    {:ok, _} = Games.admin_delete_game(game)

    opts =
      []
      |> then(
        &if socket.assigns.status_filter,
          do: [{:status, String.to_atom(socket.assigns.status_filter)} | &1],
          else: &1
      )

    games = Games.list_all_games(opts)

    {:noreply,
     socket
     |> assign(:games, games)
     |> put_flash(:info, gettext("Game deleted permanently."))}
  end

  def status_badge_color(:draft), do: "badge-ghost"
  def status_badge_color(:published), do: "badge-success"
  def status_badge_color(:archived), do: "badge-neutral"
  def status_badge_color(_), do: "badge-ghost"
end
