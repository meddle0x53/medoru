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

  alias Medoru.Learning.{UserProgress, LessonProgress}
  alias Medoru.Content.{Lesson, Word}

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

        # Update user stats
        with {:ok, _} <- result do
          update_user_stats_on_lesson_complete(user_id)
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

        %UserProgress{}
        |> UserProgress.changeset(attrs)
        |> Repo.insert()

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

        %UserProgress{}
        |> UserProgress.changeset(attrs)
        |> Repo.insert()

      existing_progress ->
        {:ok, existing_progress}
    end
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
end
