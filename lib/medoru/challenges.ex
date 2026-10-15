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

    readings = kun_on_readings(ids)

    Enum.map(kanji, fn k -> serialize_pool_kanji(k, Map.get(words, k.id), readings) end)
  end

  @doc """
  The drawable pool for Kanji Master N5: ALL N5 kanji with stroke data, not
  user-specific. Same map shape as `kanji_master_pool/1`, but the question
  word is the RAREST word with `usage_frequency < 1000` using the kanji
  (highest value below the cap = least frequent); `nil` when no such word
  exists, in which case the client falls back to a readings question.
  """
  def kanji_master_n5_pool, do: jlpt_pool([5])

  @doc """
  The drawable pool for Kanji Master N4: ALL N4 and N5 kanji with stroke
  data, not user-specific. Same map shape and word rule as
  `kanji_master_n5_pool/0`.
  """
  def kanji_master_n4_pool, do: jlpt_pool([4, 5])

  defp jlpt_pool(jlpt_levels) do
    kanji =
      Repo.all(
        from k in Kanji,
          where: k.jlpt_level in ^jlpt_levels,
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
            where:
              wk.kanji_id in ^ids and not is_nil(w.usage_frequency) and w.usage_frequency < 1000,
            order_by: [asc: wk.kanji_id, desc: w.usage_frequency],
            select: {wk.kanji_id, %{text: w.text, reading: w.reading, meaning: w.meaning}}
        )
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {id, ws} -> {id, hd(ws)} end)
      end

    readings = kun_on_readings(ids)

    Enum.map(kanji, fn k -> serialize_pool_kanji(k, Map.get(words, k.id), readings) end)
  end

  # First two kun and first two on readings per kanji id.
  defp kun_on_readings([]), do: %{}

  defp kun_on_readings(ids) do
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

  defp serialize_pool_kanji(k, word, readings) do
    %{
      character: k.character,
      stroke_data: k.stroke_data,
      stroke_count: k.stroke_count,
      word: word,
      kun: readings |> Map.get(k.id, %{}) |> Map.get(:kun, []),
      on: readings |> Map.get(k.id, %{}) |> Map.get(:on, []),
      meanings: (k.meanings || []) |> Enum.take(2)
    }
  end

  @doc """
  Top 5 leaderboard entries for a mode, highest score first, with
  user/profile preloaded so linked entries can link to the profile.
  Anonymous entries have no user and show their `anonymous_name`.
  """
  def get_leaderboard(mode \\ "master") do
    KanjiMasterScore
    |> where([s], s.mode == ^mode)
    |> order_by([s], desc: s.score)
    |> limit(5)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  The user's leaderboard entry and rank (1-based) in a mode, or nil when
  unranked.
  """
  def get_rank_and_score(user_id, mode \\ "master") do
    score = Repo.get_by(KanjiMasterScore, user_id: user_id, mode: mode)

    if score do
      rank =
        Repo.one(
          from s in KanjiMasterScore,
            where: s.mode == ^mode and s.score > ^score.score,
            select: count(s.id)
        ) + 1

      %{rank: rank, score: score.score}
    end
  end

  @doc """
  Total number of leaderboard rows in a mode (test/support helper).
  """
  def leaderboard_entry_count(mode \\ "master") do
    Repo.one(from s in KanjiMasterScore, where: s.mode == ^mode, select: count(s.id))
  end

  @doc """
  Records a run's score for the user in a mode (upsert on
  `user_id` + `mode`).

  One row per user per mode. The stored score only increases: recording a
  lower score updates the identity (`display_mode`/`anonymous_name`) but
  keeps the higher score. Returns `{:ok, score}` or `{:error, changeset}`.
  """
  def record_score(%User{} = user, attrs) do
    attrs = Map.new(attrs)
    mode = attrs[:mode] || attrs["mode"] || "master"

    case Repo.get_by(KanjiMasterScore, user_id: user.id, mode: mode) do
      nil ->
        %KanjiMasterScore{user_id: user.id, mode: mode}
        |> KanjiMasterScore.changeset(attrs)
        |> Repo.insert()

      existing ->
        merged = merge_upsert(existing, attrs)

        existing
        |> KanjiMasterScore.changeset(merged)
        |> Repo.update()
    end
  end

  @doc """
  Records a score for an anonymous player (N5 mode only): `user_id` is nil,
  `display_mode` is forced to "anonymous" and the name is required, trimmed,
  and capped at 12 characters. Upserts on (`mode`, `anonymous_name`); the
  stored score only increases. Returns `{:ok, score}` or `{:error, changeset}`.
  """
  def record_anonymous_score(attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put(:display_mode, "anonymous")
      |> Map.put(:user_id, nil)

    mode = attrs[:mode] || attrs["mode"] || "n5"

    name =
      (attrs[:anonymous_name] || attrs["anonymous_name"])
      |> to_string()
      |> String.trim()

    case Repo.one(
           from s in KanjiMasterScore,
             where: s.mode == ^mode and is_nil(s.user_id) and s.anonymous_name == ^name
         ) do
      nil ->
        %KanjiMasterScore{mode: mode}
        |> KanjiMasterScore.changeset(attrs)
        |> Repo.insert()

      existing ->
        merged = merge_upsert(existing, Map.put(attrs, :anonymous_name, name))

        existing
        |> KanjiMasterScore.changeset(merged)
        |> Repo.update()
    end
  end

  # Identity always updates; the score only increases.
  defp merge_upsert(existing, attrs) do
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
  end
end
