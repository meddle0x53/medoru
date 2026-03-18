defmodule Medoru.Learning do
  @moduledoc """
  The Learning context.

  This context handles user progress tracking for lessons, kanji, and words.
  It provides functions to:
  - Track lesson progress (start, update, complete)
  - Track kanji/word mastery levels (0-4)
  - Generate user statistics
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Learning.{UserProgress, LessonProgress, DailyStreak, ReviewSchedule}
  alias Medoru.Content.{Lesson, Word, WordKanji}
  alias Medoru.Gamification

  # ============================================================================
  # Lesson Progress
  # ============================================================================

  @doc """
  Returns the list of lesson_progress for a user.

  ## Examples

      iex> list_lesson_progress(user_id)
      [%LessonProgress{}, ...]

  """
  def list_lesson_progress(user_id) do
    LessonProgress
    |> where([lp], lp.user_id == ^user_id)
    |> preload(:lesson)
    |> order_by([lp], desc: lp.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single lesson_progress by user and lesson.

  Returns nil if no progress exists.

  ## Examples

      iex> get_lesson_progress(user_id, lesson_id)
      %LessonProgress{}

      iex> get_lesson_progress(user_id, non_existent_lesson_id)
      nil

  """
  def get_lesson_progress(user_id, lesson_id) do
    LessonProgress
    |> where([lp], lp.user_id == ^user_id and lp.lesson_id == ^lesson_id)
    |> preload(:lesson)
    |> Repo.one()
  end

  @doc """
  Checks if a user has started a lesson.

  ## Examples

      iex> lesson_started?(user_id, lesson_id)
      true

  """
  def lesson_started?(user_id, lesson_id) do
    LessonProgress
    |> where([lp], lp.user_id == ^user_id and lp.lesson_id == ^lesson_id)
    |> Repo.exists?()
  end

  @doc """
  Checks if a user has completed a lesson.

  ## Examples

      iex> lesson_completed?(user_id, lesson_id)
      true

  """
  def lesson_completed?(user_id, lesson_id) do
    LessonProgress
    |> where(
      [lp],
      lp.user_id == ^user_id and lp.lesson_id == ^lesson_id and lp.status == :completed
    )
    |> Repo.exists?()
  end

  @doc """
  Starts a lesson for a user.

  Creates a new lesson_progress record with status :started.
  If the user has already started the lesson, returns the existing progress.

  ## Examples

      iex> start_lesson(user_id, lesson_id)
      {:ok, %LessonProgress{}}

      iex> start_lesson(user_id, already_started_lesson_id)
      {:ok, %LessonProgress{}}  # Returns existing progress

  """
  def start_lesson(user_id, lesson_id) do
    case get_lesson_progress(user_id, lesson_id) do
      nil ->
        attrs = %{
          user_id: user_id,
          lesson_id: lesson_id,
          status: :started,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        %LessonProgress{}
        |> LessonProgress.changeset(attrs)
        |> Repo.insert()

      existing_progress ->
        {:ok, existing_progress}
    end
  end

  @doc """
  Updates lesson progress percentage.

  ## Examples

      iex> update_lesson_progress(user_id, lesson_id, 50)
      {:ok, %LessonProgress{}}

  """
  def update_lesson_progress(user_id, lesson_id, percentage) do
    case get_lesson_progress(user_id, lesson_id) do
      nil ->
        {:error, :not_started}

      progress ->
        progress
        |> LessonProgress.update_progress_changeset(percentage)
        |> Repo.update()
    end
  end

  @doc """
  Completes a lesson for a user.

  Updates the status to :completed and sets completed_at.

  ## Examples

      iex> complete_lesson(user_id, lesson_id)
      {:ok, %LessonProgress{}}

  """
  def complete_lesson(user_id, lesson_id) do
    case get_lesson_progress(user_id, lesson_id) do
      nil ->
        {:error, :not_started}

      progress ->
        # Also update user stats for completed lesson
        result =
          progress
          |> LessonProgress.complete_changeset()
          |> Repo.update()

        # Update user stats and check badges
        with {:ok, _completed_progress} <- result do
          update_user_stats_on_lesson_complete(user_id)
          check_and_award_lesson_badges(user_id)
        end

        result
    end
  end

  # ============================================================================
  # User Progress (Kanji/Word Mastery)
  # ============================================================================

  @doc """
  Returns the list of user_progress for a user.

  ## Examples

      iex> list_user_progress(user_id)
      [%UserProgress{}, ...]

  """
  def list_user_progress(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id)
    |> preload([:kanji, :word])
    |> Repo.all()
  end

  @doc """
  Returns the list of kanji progress for a user.

  ## Examples

      iex> list_kanji_progress(user_id)
      [%UserProgress{}, ...]

  """
  def list_kanji_progress(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and not is_nil(up.kanji_id))
    |> preload(:kanji)
    |> Repo.all()
  end

  @doc """
  Returns the list of word progress for a user.

  ## Examples

      iex> list_word_progress(user_id)
      [%UserProgress{}, ...]

  """
  def list_word_progress(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and not is_nil(up.word_id))
    |> preload(:word)
    |> Repo.all()
  end

  @doc """
  Gets a single user_progress for a kanji.

  Returns nil if no progress exists.

  ## Examples

      iex> get_kanji_progress(user_id, kanji_id)
      %UserProgress{}

  """
  def get_kanji_progress(user_id, kanji_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and up.kanji_id == ^kanji_id)
    |> preload(:kanji)
    |> Repo.one()
  end

  @doc """
  Gets a single user_progress for a word.

  Returns nil if no progress exists.

  ## Examples

      iex> get_word_progress(user_id, word_id)
      %UserProgress{}

  """
  def get_word_progress(user_id, word_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and up.word_id == ^word_id)
    |> preload(:word)
    |> Repo.one()
  end

  @doc """
  Checks if a user has learned a specific kanji.

  ## Examples

      iex> kanji_learned?(user_id, kanji_id)
      true

  """
  def kanji_learned?(user_id, kanji_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and up.kanji_id == ^kanji_id)
    |> Repo.exists?()
  end

  @doc """
  Checks if a user has learned a specific word.

  ## Examples

      iex> word_learned?(user_id, word_id)
      true

  """
  def word_learned?(user_id, word_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and up.word_id == ^word_id)
    |> Repo.exists?()
  end

  @doc """
  Tracks that a user has learned a kanji.

  Creates a new user_progress record with mastery_level 0 (New).
  If the user has already learned this kanji, returns the existing progress.

  ## Examples

      iex> track_kanji_learned(user_id, kanji_id)
      {:ok, %UserProgress{}}

  """
  def track_kanji_learned(user_id, kanji_id) do
    case get_kanji_progress(user_id, kanji_id) do
      nil ->
        attrs = %{
          user_id: user_id,
          kanji_id: kanji_id,
          mastery_level: 0,
          times_reviewed: 0
        }

        result =
          %UserProgress{}
          |> UserProgress.changeset(attrs)
          |> Repo.insert()

        # Check kanji badges after tracking new kanji
        with {:ok, _} <- result do
          check_and_award_kanji_badges(user_id)
        end

        result

      existing_progress ->
        {:ok, existing_progress}
    end
  end

  @doc """
  Tracks that a user has learned a word.

  Creates a new user_progress record with mastery_level 0 (New).
  If the user has already learned this word, returns the existing progress.

  ## Examples

      iex> track_word_learned(user_id, word_id)
      {:ok, %UserProgress{}}

  """
  def track_word_learned(user_id, word_id) do
    case get_word_progress(user_id, word_id) do
      nil ->
        attrs = %{
          user_id: user_id,
          word_id: word_id,
          mastery_level: 0,
          times_reviewed: 0
        }

        result =
          %UserProgress{}
          |> UserProgress.changeset(attrs)
          |> Repo.insert()

        # Check word badges after tracking new word
        with {:ok, _} <- result do
          check_and_award_words_badges(user_id)
        end

        result

      existing_progress ->
        {:ok, existing_progress}
    end
  end

  @doc """
  Tracks that a user has learned multiple words.

  Takes a list of word_ids and marks them all as learned.
  Skips words that are already learned.

  ## Examples

      iex> track_words_learned(user_id, [word_id1, word_id2])
      {:ok, [%UserProgress{}, ...]}

  """
  def track_words_learned(user_id, word_ids) when is_list(word_ids) do
    results =
      word_ids
      |> Enum.map(&track_word_learned(user_id, &1))
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, progress} -> progress end)

    {:ok, results}
  end

  @doc """
  Tracks that a user has learned multiple kanji.

  Takes a list of kanji_ids and marks them all as learned.
  Skips kanji that are already learned.

  ## Examples

      iex> track_kanji_learned_batch(user_id, [kanji_id1, kanji_id2])
      {:ok, [%UserProgress{}, ...]}

  """
  def track_kanji_learned_batch(user_id, kanji_ids) when is_list(kanji_ids) do
    results =
      kanji_ids
      |> Enum.map(&track_kanji_learned(user_id, &1))
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, progress} -> progress end)

    {:ok, results}
  end

  @doc """
  Gets the list of already learned word IDs for a user.

  ## Examples

      iex> list_learned_word_ids(user_id)
      ["word-id-1", "word-id-2"]

  """
  def list_learned_word_ids(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and not is_nil(up.word_id))
    |> select([up], up.word_id)
    |> Repo.all()
  end

  @doc """
  Gets the list of already learned kanji IDs for a user.

  ## Examples

      iex> list_learned_kanji_ids(user_id)
      ["kanji-id-1", "kanji-id-2"]

  """
  def list_learned_kanji_ids(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id and not is_nil(up.kanji_id))
    |> select([up], up.kanji_id)
    |> Repo.all()
  end

  @doc """
  Updates the mastery level for a kanji.

  ## Examples

      iex> update_kanji_mastery(user_id, kanji_id, 2)
      {:ok, %UserProgress{}}

  """
  def update_kanji_mastery(user_id, kanji_id, level) when level in 0..4 do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_kanji_progress(user_id, kanji_id) do
      nil ->
        {:error, :not_learned}

      progress ->
        progress
        |> UserProgress.changeset(%{
          mastery_level: level,
          times_reviewed: progress.times_reviewed + 1,
          last_reviewed_at: now
        })
        |> Repo.update()
    end
  end

  @doc """
  Updates the mastery level for a word.

  ## Examples

      iex> update_word_mastery(user_id, word_id, 3)
      {:ok, %UserProgress{}}

  """
  def update_word_mastery(user_id, word_id, level) when level in 0..4 do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_word_progress(user_id, word_id) do
      nil ->
        {:error, :not_learned}

      progress ->
        progress
        |> UserProgress.changeset(%{
          mastery_level: level,
          times_reviewed: progress.times_reviewed + 1,
          last_reviewed_at: now
        })
        |> Repo.update()
    end
  end

  # ============================================================================
  # Statistics
  # ============================================================================

  @doc """
  Returns statistics for a user's learning progress.

  ## Examples

      iex> get_user_stats(user_id)
      %{
        total_kanji_learned: 10,
        total_words_learned: 20,
        kanji_by_mastery: %{0 => 5, 1 => 3, 2 => 2, 3 => 0, 4 => 0},
        lessons_started: 2,
        lessons_completed: 1
      }

  """
  def get_user_stats(user_id) do
    kanji_progress = list_kanji_progress(user_id)
    word_progress = list_word_progress(user_id)
    lesson_progress = list_lesson_progress(user_id)

    kanji_by_mastery =
      kanji_progress
      |> Enum.group_by(& &1.mastery_level)
      |> Map.new(fn {level, items} -> {level, length(items)} end)
      |> then(fn map ->
        # Ensure all levels 0-4 are present
        Map.merge(%{0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0}, map)
      end)

    %{
      total_kanji_learned: length(kanji_progress),
      total_words_learned: length(word_progress),
      kanji_by_mastery: kanji_by_mastery,
      lessons_started: length(lesson_progress),
      lessons_completed: lesson_progress |> Enum.filter(&(&1.status == :completed)) |> length()
    }
  end

  @doc """
  Counts kanji learned by a user in a specific lesson.

  ## Examples

      iex> count_learned_kanji_in_lesson(user_id, lesson_id)
      5

  """
  def count_learned_kanji_in_lesson(user_id, lesson_id) do
    lesson = Repo.get!(Lesson, lesson_id) |> Repo.preload(lesson_words: :word)

    word_ids = Enum.map(lesson.lesson_words, & &1.word_id)

    words =
      Word
      |> where([w], w.id in ^word_ids)
      |> preload(:word_kanjis)
      |> Repo.all()

    kanji_ids =
      words
      |> Enum.flat_map(& &1.word_kanjis)
      |> Enum.map(& &1.kanji_id)
      |> Enum.uniq()

    UserProgress
    |> where([up], up.user_id == ^user_id and up.kanji_id in ^kanji_ids)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts words learned by a user in a specific lesson.

  ## Examples

      iex> count_learned_words_in_lesson(user_id, lesson_id)
      5

  """
  def count_learned_words_in_lesson(user_id, lesson_id) do
    lesson = Repo.get!(Lesson, lesson_id) |> Repo.preload(:lesson_words)
    word_ids = Enum.map(lesson.lesson_words, & &1.word_id)

    UserProgress
    |> where([up], up.user_id == ^user_id and up.word_id in ^word_ids)
    |> Repo.aggregate(:count, :id)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp update_user_stats_on_lesson_complete(_user_id) do
    # This will be expanded in a future iteration when we integrate
    # with the gamification context
    :ok
  end

  # ============================================================================
  # Badge Award Hooks
  # ============================================================================

  defp check_and_award_lesson_badges(user_id) do
    stats = get_user_stats(user_id)
    Gamification.check_lesson_badges(user_id, stats.lessons_completed)
  end

  defp check_and_award_kanji_badges(user_id) do
    stats = get_user_stats(user_id)
    Gamification.check_kanji_badges(user_id, stats.total_kanji_learned)
  end

  defp check_and_award_words_badges(user_id) do
    stats = get_user_stats(user_id)
    Gamification.check_words_badges(user_id, stats.total_words_learned)
  end

  defp check_and_award_streak_badges(user_id, current_streak) do
    Gamification.check_streak_badges(user_id, current_streak)
  end

  # ============================================================================
  # Daily Streak
  # ============================================================================

  @doc """
  Gets or creates a daily streak record for a user.

  ## Examples

      iex> get_or_create_daily_streak(user_id)
      %DailyStreak{}

  """
  def get_or_create_daily_streak(user_id) do
    case Repo.get_by(DailyStreak, user_id: user_id) do
      nil ->
        {:ok, streak} =
          %DailyStreak{}
          |> DailyStreak.changeset(%{user_id: user_id})
          |> Repo.insert()

        streak

      streak ->
        streak
    end
  end

  @doc """
  Gets a user's daily streak.

  Returns nil if no streak record exists.

  ## Examples

      iex> get_daily_streak(user_id)
      %DailyStreak{}

      iex> get_daily_streak(user_id_without_streak)
      nil

  """
  def get_daily_streak(user_id) do
    Repo.get_by(DailyStreak, user_id: user_id)
  end

  @doc """
  Updates a user's daily streak after completing a study session.

  Calculates if the streak should be continued, reset, or started fresh.

  ## Examples

      iex> update_streak(user_id)
      {:ok, %DailyStreak{current_streak: 5, longest_streak: 10}}

  """
  def update_streak(user_id) do
    streak = get_or_create_daily_streak(user_id)
    today = Date.utc_today()

    new_streak =
      case streak.last_study_date do
        nil ->
          # First time studying
          %{current_streak: 1, longest_streak: 1, last_study_date: today}

        ^today ->
          # Already studied today, no change
          %{}

        last_date ->
          yesterday = Date.add(today, -1)

          if Date.compare(last_date, yesterday) == :eq do
            # Studied yesterday, continue streak
            new_current = streak.current_streak + 1
            new_longest = max(new_current, streak.longest_streak)

            %{
              current_streak: new_current,
              longest_streak: new_longest,
              last_study_date: today
            }
          else
            # Streak broken, start new
            %{current_streak: 1, last_study_date: today}
          end
      end

    result =
      streak
      |> DailyStreak.changeset(new_streak)
      |> Repo.update()

    # Check streak badges after updating streak
    with {:ok, updated_streak} <- result do
      check_and_award_streak_badges(user_id, updated_streak.current_streak)
    end

    result
  end

  @doc """
  Checks if a user has studied today.

  ## Examples

      iex> studied_today?(user_id)
      true

  """
  def studied_today?(user_id) do
    case get_daily_streak(user_id) do
      nil -> false
      streak -> streak.last_study_date == Date.utc_today()
    end
  end

  # ============================================================================
  # Review Schedule (SRS)
  # ============================================================================

  @doc """
  Gets the review schedule for a user progress entry.

  Returns nil if no schedule exists.

  ## Examples

      iex> get_review_schedule(user_id, user_progress_id)
      %ReviewSchedule{}

  """
  def get_review_schedule(user_id, user_progress_id) do
    ReviewSchedule
    |> where([rs], rs.user_id == ^user_id and rs.user_progress_id == ^user_progress_id)
    |> Repo.one()
  end

  @doc """
  Gets or creates a review schedule for a user progress entry.

  ## Examples

      iex> get_or_create_review_schedule(user_id, user_progress_id)
      %ReviewSchedule{}

  """
  def get_or_create_review_schedule(user_id, user_progress_id) do
    case get_review_schedule(user_id, user_progress_id) do
      nil ->
        attrs = %{
          user_id: user_id,
          user_progress_id: user_progress_id,
          next_review_at: DateTime.utc_now() |> DateTime.truncate(:second),
          interval: 1,
          ease_factor: 2.5,
          repetitions: 0
        }

        {:ok, schedule} =
          %ReviewSchedule{}
          |> ReviewSchedule.changeset(attrs)
          |> Repo.insert()

        schedule

      schedule ->
        schedule
    end
  end

  @doc """
  Updates the review schedule based on review result using SM-2 algorithm.

  Quality: 0-5 scale (0=complete blackout, 5=perfect response)
  - 0-2: Failed review, reset interval
  - 3-5: Successful review, increase interval

  ## Examples

      iex> record_review(user_id, user_progress_id, 4)
      {:ok, %ReviewSchedule{interval: 3, ease_factor: 2.6}}

  """
  def record_review(user_id, user_progress_id, quality) when quality in 0..5 do
    schedule = get_or_create_review_schedule(user_id, user_progress_id)

    # SM-2 algorithm parameters
    {new_interval, new_ease_factor, new_repetitions} =
      calculate_sm2(schedule.interval, schedule.ease_factor, schedule.repetitions, quality)

    next_review_at =
      DateTime.utc_now()
      |> DateTime.add(new_interval, :day)
      |> DateTime.truncate(:second)

    schedule
    |> ReviewSchedule.changeset(%{
      interval: new_interval,
      ease_factor: new_ease_factor,
      repetitions: new_repetitions,
      next_review_at: next_review_at
    })
    |> Repo.update()
  end

  # SM-2 algorithm implementation
  defp calculate_sm2(interval, ease_factor, repetitions, quality) do
    # Minimum ease factor to prevent excessive intervals
    min_ease_factor = 1.3

    if quality < 3 do
      # Failed review - reset repetitions, keep ease factor, reset interval to 1
      {1, ease_factor, 0}
    else
      # Successful review
      new_repetitions = repetitions + 1

      new_interval =
        cond do
          new_repetitions == 1 -> 1
          new_repetitions == 2 -> 3
          true -> round(interval * ease_factor)
        end

      # Update ease factor
      new_ease_factor = ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
      new_ease_factor = max(new_ease_factor, min_ease_factor)

      {new_interval, new_ease_factor, new_repetitions}
    end
  end

  @doc """
  Gets words due for review for a user.

  Returns a list of user_progress entries with preloaded words/kanji that are due.

  ## Examples

      iex> get_due_reviews(user_id, limit: 10)
      [%UserProgress{word: %Word{}}, ...]

  """
  def get_due_reviews(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    now = DateTime.utc_now()

    UserProgress
    |> join(:inner, [up], rs in ReviewSchedule, on: rs.user_progress_id == up.id)
    |> where([up, rs], up.user_id == ^user_id and not is_nil(up.word_id))
    |> where([_, rs], rs.next_review_at <= ^now)
    |> preload([:word, :kanji])
    |> order_by([_, rs], asc: rs.next_review_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Counts the number of words due for review for a user.

  ## Examples

      iex> count_due_reviews(user_id)
      15

  """
  def count_due_reviews(user_id) do
    now = DateTime.utc_now()

    ReviewSchedule
    |> where([rs], rs.user_id == ^user_id and rs.next_review_at <= ^now)
    |> Repo.aggregate(:count, :id)
  end

  # ============================================================================
  # Daily Review Generation
  # ============================================================================

  @doc """
  Generates a daily review session for a user.

  Combines:
  1. Words due for review (SRS-based)
  2. New words to learn (if daily goal not met)

  Returns a list of user_progress entries ready for review.

  ## Examples

      iex> generate_daily_review(user_id, daily_goal: 10)
      %{
        reviews: [%UserProgress{}, ...],
        new_words: [%UserProgress{}, ...],
        total_count: 12
      }

  """
  def generate_daily_review(user_id, opts \\ []) do
    daily_goal = Keyword.get(opts, :daily_goal, 10)
    new_word_limit = Keyword.get(opts, :new_word_limit, 5)

    # Get words due for review
    due_reviews = get_due_reviews(user_id, limit: daily_goal)
    due_count = length(due_reviews)

    # Calculate how many new words to add
    new_words_needed = max(0, daily_goal - due_count)
    new_words_needed = min(new_words_needed, new_word_limit)

    # Get new words (learned but not yet reviewed, or not yet scheduled)
    new_words = get_new_words_for_review(user_id, limit: new_words_needed)

    %{
      reviews: due_reviews,
      new_words: new_words,
      review_count: due_count,
      new_word_count: length(new_words),
      total_count: due_count + length(new_words)
    }
  end

  @doc """
  Gets new words for a user that haven't been scheduled for review yet.

  These are words the user has learned but haven't reviewed yet.

  ## Examples

      iex> get_new_words_for_review(user_id, limit: 5)
      [%UserProgress{word: %Word{}}, ...]

  """
  def get_new_words_for_review(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    query =
      from up in UserProgress,
        where: up.user_id == ^user_id and not is_nil(up.word_id),
        left_join: rs in ReviewSchedule,
        on: rs.user_progress_id == up.id,
        where: is_nil(rs.id) or rs.repetitions == 0,
        preload: [:word, :kanji],
        order_by: [asc: up.inserted_at],
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets daily review statistics for the dashboard.

  ## Examples

      iex> get_daily_review_stats(user_id)
      %{
        due_count: 5,
        new_available: 3,
        studied_today: true,
        current_streak: 7,
        longest_streak: 14,
        daily_goal: 10
      }

  """
  def get_daily_review_stats(user_id) do
    streak = get_daily_streak(user_id)
    due_count = count_due_reviews(user_id)
    new_available = count_new_words_available(user_id)
    studied_today = studied_today?(user_id)

    %{
      due_count: due_count,
      new_available: new_available,
      studied_today: studied_today,
      current_streak: if(streak, do: streak.current_streak, else: 0),
      longest_streak: if(streak, do: streak.longest_streak, else: 0),
      daily_goal: 10
    }
  end

  @doc """
  Counts how many new words are available for review.

  ## Examples

      iex> count_new_words_available(user_id)
      15

  """
  def count_new_words_available(user_id) do
    query =
      from up in UserProgress,
        where: up.user_id == ^user_id,
        left_join: rs in ReviewSchedule,
        on: rs.user_progress_id == up.id,
        where: is_nil(rs.id) or rs.repetitions == 0

    Repo.aggregate(query, :count, :id)
  end

  # ============================================================================
  # Auto-learn Kanji Logic
  # ============================================================================

  @doc """
  Checks if all words containing a kanji are learned, and if so,
  automatically marks the kanji as learned.

  ## Examples

      iex> check_and_auto_learn_kanji(user_id, kanji_id)
      {:ok, %UserProgress{}} | nil

  """
  def check_and_auto_learn_kanji(user_id, kanji_id) do
    # First check if kanji is already learned
    if kanji_learned?(user_id, kanji_id) do
      nil
    else
      # Get all words that contain this kanji
      word_ids =
        from(wk in WordKanji,
          where: wk.kanji_id == ^kanji_id,
          select: wk.word_id
        )
        |> Repo.all()

      # Check if there are any words for this kanji
      if Enum.empty?(word_ids) do
        nil
      else
        # Count how many of these words are learned
        learned_count =
          UserProgress
          |> where([up], up.user_id == ^user_id and up.word_id in ^word_ids)
          |> Repo.aggregate(:count, :id)

        # If all words are learned, mark kanji as learned
        if learned_count == length(word_ids) do
          track_kanji_learned(user_id, kanji_id)
        else
          nil
        end
      end
    end
  end

  # ============================================================================
  # Daily Tests
  # ============================================================================

  @doc """
  Gets or creates a daily test for a user.

  If the user already has a daily test for today, returns that test.
  Otherwise, generates a new daily test based on SRS due reviews and new words.

  ## Examples

      iex> get_or_create_daily_test(user_id)
      {:ok, %Test{}}

  """
  def get_or_create_daily_test(user_id) do
    Medoru.Learning.DailyTestGenerator.get_or_create_daily_test(user_id)
  end

  @doc """
  Checks if a user has already completed their daily test today.

  ## Examples

      iex> daily_test_completed_today?(user_id)
      true

  """
  def daily_test_completed_today?(user_id) do
    Medoru.Learning.DailyTestGenerator.daily_test_completed_today?(user_id)
  end

  @doc """
  Gets today's daily test for a user if one exists.

  Returns nil if no daily test exists for today.

  ## Examples

      iex> get_todays_daily_test(user_id)
      %Test{}

      iex> get_todays_daily_test(user_id_without_test)
      nil

  """
  def get_todays_daily_test(user_id) do
    Medoru.Learning.DailyTestGenerator.get_todays_daily_test(user_id)
  end

  @doc """
  Returns the daily test status for a user.

  Includes information about:
  - Whether a test exists for today
  - Whether it has been completed
  - Count of due reviews and new words available

  ## Examples

      iex> get_daily_test_status(user_id)
      %{
        has_test: true,
        completed: false,
        test_id: "uuid",
        due_count: 5,
        new_available: 3,
        total_items: 8
      }

  """
  def get_daily_test_status(user_id) do
    daily_stats = get_daily_review_stats(user_id)
    todays_test = get_todays_daily_test(user_id)

    if todays_test do
      # Check if there's a completed session
      completed_today = daily_test_completed_today?(user_id)

      %{
        has_test: true,
        completed: completed_today,
        test_id: todays_test.id,
        due_count: daily_stats.due_count,
        new_available: daily_stats.new_available,
        total_items: length(todays_test.test_steps || [])
      }
    else
      %{
        has_test: false,
        completed: false,
        test_id: nil,
        due_count: daily_stats.due_count,
        new_available: daily_stats.new_available,
        total_items: 0
      }
    end
  end
end
