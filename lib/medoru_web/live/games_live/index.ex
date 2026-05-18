defmodule MedoruWeb.GamesLive.Index do
  @moduledoc """
  Shows all games the user has access to across all their classrooms.
  """
  use MedoruWeb, :live_view

  alias Medoru.Games
  alias Medoru.SiteSettings

  @game_type_labels %{
    "memory_cards" => gettext("Memory Cards"),
    "kana_memory_cards" => gettext("Kana Memory"),
    "kana_falling" => gettext("Kana Cascade"),
    "kanji_falling" => gettext("Kanji Cascade"),
    "words_falling" => gettext("Words Cascade")
  }

  @game_type_icons %{
    "memory_cards" => "hero-squares-2x2",
    "kana_memory_cards" => "hero-squares-2x2",
    "kana_falling" => "hero-bolt",
    "kanji_falling" => "hero-bolt",
    "words_falling" => "hero-book-open"
  }

  @skill_level_colors %{
    1 => "bg-success/10 text-success border-success/20",
    2 => "bg-info/10 text-info border-info/20",
    3 => "bg-purple-500/20 text-purple-500 border-purple-500/40",
    4 => "bg-error/10 text-error border-error/20",
    5 => "bg-warning/10 text-warning border-warning/20"
  }

  @skill_level_card_bgs %{
    1 => "bg-success/5 border-success/20 hover:border-success/40",
    2 => "bg-info/5 border-info/20 hover:border-info/40",
    3 => "bg-purple-500/5 border-purple-500/20 hover:border-purple-500/40",
    4 => "bg-error/5 border-error/20 hover:border-error/40",
    5 => "bg-warning/5 border-warning/20 hover:border-warning/40"
  }

  @skill_level_labels %{
    1 => gettext("Beginner"),
    2 => gettext("Elementary"),
    3 => gettext("Intermediate"),
    4 => gettext("Advanced"),
    5 => gettext("Expert")
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    {games, games_by_classroom} =
      if user do
        games = Games.list_user_games(user.id)

        games_by_classroom =
          games
          |> Enum.group_by(& &1.classroom)
          |> Enum.sort_by(fn {classroom, _} -> classroom.name end)

        {games, games_by_classroom}
      else
        case SiteSettings.featured_classroom_id() do
          nil ->
            {[], []}

          classroom_id ->
            games = Games.list_classroom_games(classroom_id, status: :published)

            games_by_classroom =
              games
              |> Enum.group_by(& &1.classroom)
              |> Enum.sort_by(fn {classroom, _} -> classroom.name end)

            {games, games_by_classroom}
        end
      end

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
                    navigate={"#{play_path(game)}?return_to=/games"}
                    class={[
                      "card shadow-sm hover:shadow-md transition-all",
                      skill_level_card_bg(game.skill_level)
                    ]}
                  >
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between">
                        <div class="flex items-center gap-3">
                          <div class={[
                            "w-10 h-10 rounded-full flex items-center justify-center border",
                            skill_level_color(game.skill_level)
                          ]}>
                            <.icon name={game_type_icon(game.type)} class="w-5 h-5" />
                          </div>
                          <div>
                            <div class="font-semibold text-base-content">{game.name}</div>
                            <div class="text-sm text-base-content/60 flex items-center gap-2">
                              {game_type_label(game.type)}
                              <span class={[
                                "text-xs px-2 py-0.5 rounded-full border font-medium",
                                skill_level_color(game.skill_level)
                              ]}>
                                {skill_level_label(game.skill_level)}
                              </span>
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
      "words_falling" -> ~p"/classrooms/#{classroom_id}/words-falling-games/#{game.id}"
      _ -> ~p"/classrooms/#{classroom_id}/games/#{game.id}"
    end
  end

  defp game_type_label(type), do: Map.get(@game_type_labels, type, type)
  defp game_type_icon(type), do: Map.get(@game_type_icons, type, "hero-puzzle-piece")

  defp skill_level_color(level),
    do: Map.get(@skill_level_colors, level, "bg-base-200 text-base-content border-base-300")

  defp skill_level_label(level), do: Map.get(@skill_level_labels, level, "")

  defp skill_level_card_bg(level),
    do: Map.get(@skill_level_card_bgs, level, "bg-base-100 border-base-300 hover:border-primary")
end
