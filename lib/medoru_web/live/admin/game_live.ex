defmodule MedoruWeb.Admin.GameLive do
  @moduledoc """
  Admin-only game page for Kill Medoru! MVP.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Accounts.UserStats
  alias Medoru.Repo
  alias Medoru.Content

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
      |> Enum.filter(fn k -> k.stroke_count && k.stroke_count > 0 end)
      |> Enum.map(fn k ->
        meanings = Enum.take(k.meanings || [], 2)

        on_readings =
          k.kanji_readings |> Enum.filter(&(&1.reading_type == :on)) |> Enum.map(& &1.reading)

        kun_readings =
          k.kanji_readings |> Enum.filter(&(&1.reading_type == :kun)) |> Enum.map(& &1.reading)

        stroke_data = Map.get(k, :stroke_data) || %{}

        %{
          character: k.character,
          meanings: meanings,
          on_readings: on_readings,
          kun_readings: kun_readings,
          stroke_count: k.stroke_count,
          stroke_data: stroke_data
        }
      end)

    word_list =
      user.id
      |> Learning.list_learned_words(limit: 30)
      |> Enum.map(fn w ->
        %{word: w.text, reading: w.reading, meaning: w.meaning}
      end)

    user_level =
      case Repo.get_by(UserStats, user_id: user.id) do
        %UserStats{level: level} -> level
        _ -> 1
      end

    # Fetch stroke data for weapon kanji (力 - chikara)
    weapon_kanji = Content.get_kanji_by_character("力")

    weapon_kanji_strokes =
      if weapon_kanji && weapon_kanji.stroke_data do
        %{
          character: weapon_kanji.character,
          strokes: weapon_kanji.stroke_data["strokes"] || []
        }
      else
        %{character: "力", strokes: []}
      end

    # Fetch stroke data for shield kanji (盾 - tate)
    shield_kanji = Content.get_kanji_by_character("盾")

    shield_kanji_strokes =
      if shield_kanji && shield_kanji.stroke_data do
        %{
          character: shield_kanji.character,
          strokes: shield_kanji.stroke_data["strokes"] || []
        }
      else
        %{character: "盾", strokes: []}
      end

    game_data = %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      kanji_list: kanji_list,
      word_list: word_list,
      weapon_kanji_strokes: weapon_kanji_strokes,
      shield_kanji_strokes: shield_kanji_strokes
    }

    socket =
      socket
      |> assign(:page_title, "Kill Medoru! - Battle MVP")
      |> assign(:game_data, Jason.encode!(game_data))

    {:ok, socket}
  end
end
