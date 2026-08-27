defmodule MedoruWeb.GameApiController do
  @moduledoc """
  API controller for The Hollow Ouroboros game events.
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts.UserStats
  alias Medoru.Content
  alias Medoru.GameSaves
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

    # Mark any words learned during the run as learned. This is idempotent, so
    # duplicate calls are safe.
    learned_word_ids = params["learned_word_ids"] || []

    if is_list(learned_word_ids) do
      for word_id <- learned_word_ids do
        Learning.track_word_learned_for_user(user, word_id)
      end
    end

    # Mark the run's focus kanji as learned when the run ends.
    if is_binary(params["focus_kanji"]) do
      case Content.get_kanji_by_character(params["focus_kanji"]) do
        nil -> :ok
        kanji -> Learning.track_kanji_learned(user.id, kanji.id)
      end
    end

    # Daily challenge runs award site XP based on Ouro Essence earned.
    # Regular runs still persist learned words/kanji but do not grant site XP.
    if params["daily_challenge_mode"] == true do
      earned_ouro_essence = params["earned_ouro_essence"] || 0
      xp_awarded = max(0, earned_ouro_essence * 100)

      metadata = %{
        earned_ouro_essence: earned_ouro_essence,
        victory: params["winner"] == "player"
      }

      Learning.complete_daily_challenge(
        user.id,
        "ouroboros_run",
        xp_awarded,
        metadata: metadata,
        score: earned_ouro_essence
      )
    end

    json(conn, %{status: "ok"})
  end

  def load_save(conn, _params) do
    user = conn.assigns.current_scope.current_user

    case GameSaves.get_user_save(user.id) do
      nil ->
        json(conn, %{status: "no_save"})

      save ->
        json(conn, %{
          status: "ok",
          save_data: save.save_data,
          version: save.version,
          updated_at: save.updated_at
        })
    end
  end

  def save_save(conn, params) do
    user = conn.assigns.current_scope.current_user
    save_data = params["save_data"] || %{}
    version = params["version"] || 1

    case GameSaves.save_user_save(user.id, %{save_data: save_data, version: version}) do
      {:ok, save} ->
        json(conn, %{status: "ok", updated_at: save.updated_at})

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: errors})
    end
  end
end
