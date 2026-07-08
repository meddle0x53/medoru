defmodule MedoruWeb.GameApiController do
  @moduledoc """
  API controller for The Hollow Ouroboros game events.
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts
  alias Medoru.Accounts.UserStats
  alias Medoru.Content
  alias Medoru.Learning
  alias Medoru.Repo

  def user_data(conn, _params) do
    user = conn.assigns.current_scope.current_user

    kanji_list =
      user.id
      |> Learning.list_learned_kanji(limit: 50)
      |> Enum.map(fn k ->
        readings = List.first(k.meanings || [], "")
        %{character: k.character, readings: [readings]}
      end)

    # Merge both progress tables so the game always sees the user's full learned
    # word pool regardless of the learning_language setting.
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
          word_type: w.word_type,
          core_rank: w.core_rank,
          usage_frequency: w.usage_frequency,
          difficulty: w.difficulty
        }
      end)

    user_level =
      case Repo.get_by(UserStats, user_id: user.id) do
        %UserStats{level: level} -> level
        _ -> 1
      end

    json(conn, %{
      user_id: user.id,
      name: user.name || user.email,
      level: user_level,
      learning_language: user.learning_language,
      kanji_list: kanji_list,
      word_list: word_list
    })
  end

  def run_result(conn, params) do
    user = conn.assigns.current_scope.current_user

    # Log the run result for now. In the future this will save to DB.
    require Logger
    Logger.info("Game run result for user #{user.id}: #{inspect(params)}")

    # Grant a small XP reward for winning
    if params["winner"] == "player" do
      Accounts.add_xp(user, 50,
        source_type: "game_battle",
        description: "Won a battle in The Hollow Ouroboros"
      )
    end

    # Mark the run's focus kanji as learned when the run is completed.
    if params["winner"] == "player" && is_binary(params["focus_kanji"]) do
      case Content.get_kanji_by_character(params["focus_kanji"]) do
        nil -> :ok
        kanji -> Learning.track_kanji_learned(user.id, kanji.id)
      end
    end

    json(conn, %{status: "ok"})
  end
end
