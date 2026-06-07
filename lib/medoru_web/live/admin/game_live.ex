defmodule MedoruWeb.Admin.GameLive do
  @moduledoc """
  Admin-only game page for Kill Medoru! MVP.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Accounts.UserStats
  alias Medoru.Repo

  embed_templates "game_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {game(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Fetch user learning data for the game
    kanji_list =
      user.id
      |> Learning.list_learned_kanji(limit: 50)
      |> Enum.map(fn k ->
        readings = List.first(k.meanings || [], "")
        %{character: k.character, readings: [readings]}
      end)

    word_list =
      user.id
      |> Learning.list_learned_words(limit: 30)
      |> Enum.map(fn w ->
        %{word: w.text, reading: w.reading}
      end)

    user_level =
      case Repo.get_by(UserStats, user_id: user.id) do
        %UserStats{level: level} -> level
        _ -> 1
      end

    game_data = %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      kanji_list: kanji_list,
      word_list: word_list
    }

    socket =
      socket
      |> assign(:page_title, "Kill Medoru! - Battle MVP")
      |> assign(:game_data, Jason.encode!(game_data))

    {:ok, socket}
  end
end
