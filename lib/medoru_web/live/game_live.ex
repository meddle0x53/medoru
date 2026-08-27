defmodule MedoruWeb.GameLive do
  @moduledoc """
  Public game page for The Hollow Ouroboros.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Accounts.UserStats
  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.Kanji

  import Ecto.Query

  # Characters that appear in ability kanji pools. Stroke data is kept for these
  # in the embedded all_kanji list so battle challenges can pick randomly from
  # the pool without shipping strokes for all 5,000+ kanji.
  @ability_kanji_chars (fn ->
                          pattern = Path.join(File.cwd!(), "assets/js/game/data/abilities/*.json")

                          pattern
                          |> Path.wildcard()
                          |> Enum.flat_map(fn path ->
                            case File.read(path) do
                              {:ok, contents} ->
                                case Jason.decode(contents) do
                                  {:ok, %{"abilities" => abilities}} when is_list(abilities) ->
                                    Enum.flat_map(abilities, fn ability ->
                                      chars = Map.get(ability, "kanjiPool", [])

                                      if is_binary(ability["kanji"]),
                                        do: [ability["kanji"] | chars],
                                        else: chars
                                    end)

                                  _ ->
                                    []
                                end

                              _ ->
                                []
                            end
                          end)
                          |> Enum.filter(&is_binary/1)
                          |> Enum.uniq()
                        end).()

  @impl true
  def mount(params, session, socket) do
    user = socket.assigns.current_scope.current_user

    daily_challenge_mode = params["daily_challenge"] == "1"
    game_data = build_game_data(user, session, daily_challenge_mode: daily_challenge_mode)

    socket =
      socket
      |> assign(:page_title, "RPG Game")
      |> assign(:game_data, Jason.encode!(game_data))
      |> assign(:daily_challenge_mode, daily_challenge_mode)

    {:ok, socket}
  end

  @doc """
  Builds the game data payload shared between the public and admin game pages.
  """
  def build_game_data(user, session, opts \\ []) do
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

    locale = session["locale"] || "en"

    all_kanji =
      Kanji
      |> order_by([k], asc: k.frequency)
      |> Repo.all()
      |> Repo.preload(:kanji_readings)
      |> Enum.map(fn k ->
        meanings = Content.get_localized_kanji_meanings(k, locale) |> Enum.take(2)

        on_readings =
          k.kanji_readings
          |> Enum.filter(&(&1.reading_type == :on))
          |> Enum.map(& &1.reading)
          |> Enum.take(3)

        kun_readings =
          k.kanji_readings
          |> Enum.filter(&(&1.reading_type == :kun))
          |> Enum.map(& &1.reading)
          |> Enum.take(3)

        readings = (on_readings ++ kun_readings) |> Enum.take(5)

        %{
          id: k.id,
          character: k.character,
          jlpt_level: k.jlpt_level,
          school_level: k.school_level,
          frequency: k.frequency,
          meanings: meanings,
          on_readings: on_readings,
          kun_readings: kun_readings,
          readings: readings,
          stroke_count: k.stroke_count,
          stroke_data: if(k.character in @ability_kanji_chars, do: k.stroke_data, else: nil)
        }
      end)

    user_level =
      case Repo.get_by(UserStats, user_id: user.id) do
        %UserStats{level: level} -> level
        _ -> 1
      end

    learned_word_ids = Enum.map(learned_words, & &1.id)

    vocabulary =
      Content.Word
      |> where([w], w.difficulty <= ^user_level and w.id not in ^learned_word_ids)
      |> where([w], not is_nil(w.meaning) and not is_nil(w.reading))
      |> order_by([w], asc: w.usage_frequency)
      |> limit(200)
      |> Repo.all()
      |> Enum.map(fn w ->
        %{
          id: w.id,
          word: w.text,
          reading: w.reading,
          meaning: Content.get_localized_meaning(w, locale),
          usage_frequency: w.usage_frequency,
          difficulty: w.difficulty,
          word_type: w.word_type,
          image_path: w.image_path,
          example_reading: w.example_reading,
          example_meaning: w.example_meaning
        }
      end)

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

    learned_kanji_ids = Learning.list_learned_kanji_ids(user.id)

    learned_kanji_chars =
      from(k in Kanji, where: k.id in ^learned_kanji_ids, select: k.character)
      |> Repo.all()
      |> MapSet.new()
      |> MapSet.to_list()

    %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      daily_challenge_mode: Keyword.get(opts, :daily_challenge_mode, false),
      kanji_list: kanji_list,
      all_kanji: all_kanji,
      learned_kanji_chars: learned_kanji_chars,
      word_list: word_list,
      vocabulary: vocabulary,
      weapon_kanji_strokes: weapon_kanji_strokes,
      shield_kanji_strokes: shield_kanji_strokes,
      shield_kanji_pool_strokes: shield_kanji_pool_strokes
    }
  end
end
