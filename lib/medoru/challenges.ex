defmodule Medoru.Challenges do
  @moduledoc """
  Permanent learner challenges (as opposed to daily challenges).

  Currently one challenge: Kanji Master — an infinite kanji-writing
  survival game with a cross-user leaderboard. Scores are client-graded
  (same trust model as the other games) and recorded here.
  """

  import Ecto.Query

  alias Medoru.Accounts.User
  alias Medoru.Challenges.KanjiMasterScore
  alias Medoru.Content.Kanji
  alias Medoru.Content.KanjiReading
  alias Medoru.Content.Word
  alias Medoru.Content.WordKanji
  alias Medoru.Learning.UserProgress
  alias Medoru.Repo

  @min_learned_kanji 50

  @doc """
  Number of kanji the user has learned (progress rows with a kanji).
  """
  def learned_kanji_count(%User{} = user) do
    Repo.one(
      from up in UserProgress,
        where: up.user_id == ^user.id and not is_nil(up.kanji_id),
        select: count(up.id)
    )
  end

  @doc """
  Only users that know at least #{@min_learned_kanji} kanji can play.
  """
  def eligible?(%User{} = user), do: learned_kanji_count(user) >= @min_learned_kanji

  @doc """
  The drawable kanji pool for the Kanji Master game: the user's learned
  kanji that have stroke data, plus question data for each kanji: the
  most frequent word using it (lower `usage_frequency` = more frequent), and
  the first two kun/on readings.

  Returns maps with `character`, `stroke_data`, `stroke_count`, `word`
  (`%{text, reading, meaning}` or nil), `kun` and `on` (lists of strings),
  and `meanings` (the kanji's first two meanings).
  """
  def kanji_master_pool(%User{} = user) do
    kanji =
      Repo.all(
        from up in UserProgress,
          join: k in Kanji,
          on: k.id == up.kanji_id,
          where: up.user_id == ^user.id and not is_nil(up.kanji_id),
          where:
            not is_nil(k.stroke_data) and fragment("?->'strokes' != '[]'::jsonb", k.stroke_data),
          select: k
      )

    ids = Enum.map(kanji, & &1.id)

    words =
      if ids == [] do
        %{}
      else
        Repo.all(
          from wk in WordKanji,
            join: w in Word,
            on: w.id == wk.word_id,
            where: wk.kanji_id in ^ids,
            order_by: [asc: wk.kanji_id, asc: w.usage_frequency],
            select: {wk.kanji_id, %{text: w.text, reading: w.reading, meaning: w.meaning}}
        )
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {id, ws} -> {id, hd(ws)} end)
      end

    readings =
      if ids == [] do
        %{}
      else
        Repo.all(
          from r in KanjiReading,
            where: r.kanji_id in ^ids and r.reading_type in [:kun, :on],
            order_by: [asc: r.kanji_id, asc: r.position],
            select: {r.kanji_id, r.reading_type, r.reading}
        )
        |> Enum.group_by(&elem(&1, 0))
        |> Map.new(fn {id, rows} ->
          grouped =
            Enum.reduce(rows, %{}, fn {_, type, reading}, acc ->
              Map.update(acc, type, [reading], &(&1 ++ [reading]))
            end)

          {id,
           %{
             kun: grouped |> Map.get(:kun, []) |> Enum.take(2),
             on: grouped |> Map.get(:on, []) |> Enum.take(2)
           }}
        end)
      end

    Enum.map(kanji, fn k ->
      %{
        character: k.character,
        stroke_data: k.stroke_data,
        stroke_count: k.stroke_count,
        word: Map.get(words, k.id),
        kun: readings |> Map.get(k.id, %{}) |> Map.get(:kun, []),
        on: readings |> Map.get(k.id, %{}) |> Map.get(:on, []),
        meanings: (k.meanings || []) |> Enum.take(2)
      }
    end)
  end

  @doc """
  Top 5 leaderboard entries, highest score first, with user/profile
  preloaded so linked entries can link to the profile.
  """
  def get_leaderboard do
    KanjiMasterScore
    |> order_by([s], desc: s.score)
    |> limit(5)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  The user's leaderboard entry and rank (1-based), or nil when unranked.
  """
  def get_rank_and_score(user_id) do
    score = Repo.get_by(KanjiMasterScore, user_id: user_id)

    if score do
      rank =
        Repo.one(
          from s in KanjiMasterScore,
            where: s.score > ^score.score,
            select: count(s.id)
        ) + 1

      %{rank: rank, score: score.score}
    end
  end

  @doc """
  Total number of leaderboard rows (test/support helper).
  """
  def leaderboard_entry_count do
    Repo.one(from s in KanjiMasterScore, select: count(s.id))
  end

  @doc """
  Records a run's score for the user (upsert on `user_id`).

  One row per user. The stored score only increases: recording a lower
  score updates the identity (`display_mode`/`anonymous_name`) but keeps
  the higher score. Returns `{:ok, score}` or `{:error, changeset}`.
  """
  def record_score(%User{} = user, attrs) do
    attrs = Map.new(attrs)

    case Repo.get_by(KanjiMasterScore, user_id: user.id) do
      nil ->
        %KanjiMasterScore{user_id: user.id}
        |> KanjiMasterScore.changeset(attrs)
        |> Repo.insert()

      existing ->
        merged =
          if existing.score >= (attrs[:score] || attrs["score"] || 0) do
            %{
              display_mode: attrs[:display_mode] || attrs["display_mode"],
              anonymous_name: attrs[:anonymous_name] || attrs["anonymous_name"]
            }
          else
            %{
              score: attrs[:score] || attrs["score"],
              display_mode: attrs[:display_mode] || attrs["display_mode"],
              anonymous_name: attrs[:anonymous_name] || attrs["anonymous_name"]
            }
          end

        existing
        |> KanjiMasterScore.changeset(merged)
        |> Repo.update()
    end
  end
end
