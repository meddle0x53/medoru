defmodule MedoruWeb.Admin.GameLive do
  @moduledoc """
  Admin-only game page for The Hollow Ouroboros MVP.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Accounts.UserStats
  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.Kanji

  import Ecto.Query

  embed_templates "game_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {game(assigns)}
    """
  end

  @impl true
  def mount(_params, session, socket) do
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

    # Some users have words in both regular progress and English-learning progress,
    # and the learning_language setting does not always match the actual data. Merge
    # both sources and de-duplicate so the game always has the full learned pool.
    regular_words = Learning.list_learned_words(user.id, limit: 1000)
    english_words = Learning.list_english_learned_words(user.id, limit: 1000)

    learned_words =
      (regular_words ++ english_words)
      |> Enum.uniq_by(& &1.id)

    word_list =
      learned_words
      |> Enum.map(fn w ->
        %{
          word: w.text,
          reading: w.reading,
          meaning: w.meaning,
          type: w.word_type,
          core_rank: w.core_rank,
          usage_frequency: w.usage_frequency,
          difficulty: w.difficulty
        }
      end)

    # Locale for localized kanji meanings.
    locale = session["locale"] || "en"

    # Full kanji collection for the pre-run Kanji Collection scene.
    all_kanji =
      Kanji
      |> order_by([k], asc: k.frequency)
      |> Repo.all()
      |> Repo.preload(:kanji_readings)
      |> Enum.map(fn k ->
        meanings = Content.get_localized_kanji_meanings(k, locale) |> Enum.take(2)

        readings =
          k.kanji_readings
          |> Enum.map(& &1.reading)
          |> Enum.take(5)

        %{
          id: k.id,
          character: k.character,
          jlpt_level: k.jlpt_level,
          school_level: k.school_level,
          frequency: k.frequency,
          meanings: meanings,
          readings: readings,
          stroke_count: k.stroke_count,
          stroke_data: k.stroke_data
        }
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

    # Stroke data for the Setup Defence kanji pool
    shield_kanji_pool = ["守", "防", "盾", "硬", "堅"]

    shield_kanji_pool_strokes =
      Map.new(shield_kanji_pool, fn char ->
        case Content.get_kanji_by_character(char) do
          %{stroke_data: data, meanings: meanings} when is_map(data) ->
            {char,
             %{
               character: char,
               strokes: data["strokes"] || [],
               meanings: Enum.take(meanings || [], 2)
             }}

          %{stroke_data: data} when is_map(data) ->
            {char, %{character: char, strokes: data["strokes"] || [], meanings: []}}

          _ ->
            {char, %{character: char, strokes: [], meanings: []}}
        end
      end)

    # All learned kanji characters (no limit) for the library learned indicator.
    learned_kanji_ids = Learning.list_learned_kanji_ids(user.id)

    learned_kanji_chars =
      from(k in Kanji, where: k.id in ^learned_kanji_ids, select: k.character)
      |> Repo.all()
      |> MapSet.new()
      |> MapSet.to_list()

    game_data = %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      kanji_list: kanji_list,
      all_kanji: all_kanji,
      learned_kanji_chars: learned_kanji_chars,
      word_list: word_list,
      weapon_kanji_strokes: weapon_kanji_strokes,
      shield_kanji_strokes: shield_kanji_strokes,
      shield_kanji_pool_strokes: shield_kanji_pool_strokes
    }

    socket =
      socket
      |> assign(:page_title, "The Hollow Ouroboros - Battle MVP")
      |> assign(:game_data, Jason.encode!(game_data))

    {:ok, socket}
  end
end
