defmodule MedoruWeb.GamesLive.Index do
  @moduledoc """
  Shows all games the user has access to across all their classrooms.
  """
  use MedoruWeb, :live_view

  alias Medoru.Games

  @game_type_labels %{
    "memory_cards" => gettext("Memory Cards"),
    "kana_memory_cards" => gettext("Kana Memory"),
    "kana_falling" => gettext("Kana Cascade"),
    "kanji_falling" => gettext("Kanji Cascade")
  }

  @game_type_icons %{
    "memory_cards" => "hero-squares-2x2",
    "kana_memory_cards" => "hero-squares-2x2",
    "kana_falling" => "hero-bolt",
    "kanji_falling" => "hero-bolt"
  }

  @game_type_colors %{
    "memory_cards" => "bg-primary/10 text-primary",
    "kana_memory_cards" => "bg-secondary/10 text-secondary",
    "kana_falling" => "bg-accent/10 text-accent",
    "kanji_falling" => "bg-info/10 text-info"
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    games = Games.list_user_games(user.id)

    # Group games by classroom
    games_by_classroom =
      games
      |> Enum.group_by(& &1.classroom)
      |> Enum.sort_by(fn {classroom, _} -> classroom.name end)

    {:ok,
     socket
     |> assign(:page_title, gettext("Games"))
     |> assign(:games, games)
     |> assign(:games_by_classroom, games_by_classroom)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Games")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("All games from your classrooms")}
          </p>
        </div>

        <%= if @games == [] do %>
          <%!-- Empty State --%>
          <div class="text-center py-16 bg-base-100 rounded-xl border border-base-300 border-dashed">
            <.icon name="hero-puzzle-piece" class="w-16 h-16 text-secondary/30 mx-auto mb-4" />
            <h3 class="text-xl font-semibold text-base-content mb-2">
              {gettext("No games available")}
            </h3>
            <p class="text-secondary max-w-md mx-auto">
              {gettext("Games will appear here when your teacher publishes them in a classroom.")}
            </p>
          </div>
        <% else %>
          <%= for {classroom, games} <- @games_by_classroom do %>
            <div class="mb-8">
              <h2 class="text-lg font-semibold text-base-content mb-3 flex items-center gap-2">
                <.icon name="hero-academic-cap" class="w-5 h-5 text-primary" />
                {classroom.name}
              </h2>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for game <- games do %>
                  <.link
                    navigate={play_path(game)}
                    class="card bg-base-100 shadow-sm border border-base-300 hover:border-primary hover:shadow-md transition-all"
                  >
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between">
                        <div class="flex items-center gap-3">
                          <div class={["w-10 h-10 rounded-full flex items-center justify-center", game_type_color(game.type)]}>
                            <.icon name={game_type_icon(game.type)} class="w-5 h-5" />
                          </div>
                          <div>
                            <div class="font-semibold text-base-content">{game.name}</div>
                            <div class="text-sm text-base-content/60">
                              {game_type_label(game.type)}
                            </div>
                          </div>
                        </div>
                        <.icon name="hero-play-circle" class="w-6 h-6 text-primary" />
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp play_path(game) do
    classroom_id = game.classroom_id

    case game.type do
      "kana_falling" -> ~p"/classrooms/#{classroom_id}/kana-falling-games/#{game.id}"
      "kanji_falling" -> ~p"/classrooms/#{classroom_id}/kanji-falling-games/#{game.id}"
      _ -> ~p"/classrooms/#{classroom_id}/games/#{game.id}"
    end
  end

  defp game_type_label(type), do: Map.get(@game_type_labels, type, type)
  defp game_type_icon(type), do: Map.get(@game_type_icons, type, "hero-puzzle-piece")
  defp game_type_color(type), do: Map.get(@game_type_colors, type, "bg-base-200 text-base-content")
end
