defmodule Medoru.Learning.DailyTestGenerator do
  @moduledoc """
  Generates daily tests for users based on words they've learned.

  Daily tests combine:
  1. Words due for review (SRS-based) - only learned words
  2. Up to 5 new words from lessons (not yet reviewed)

  IMPORTANT: Only includes words the user has learned through lessons.
  If no words are learned, returns :no_items_available error.

  Each user can have only one daily test per day.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Learning
  alias Medoru.Tests
  alias Medoru.Tests.Test
  alias Medoru.Content.Word

  # Daily test configuration
  @daily_goal 10
  @new_word_limit 5
  @distractor_count 3

  @doc """
  Gets or creates a daily test for a user.

  If the user already has a daily test for today, returns that test.
  Otherwise, generates a new daily test based on due reviews and new words.

  ## Examples

      iex> get_or_create_daily_test(user_id)
      {:ok, %Test{}}

  """
  def get_or_create_daily_test(user_id) do
    # Check for existing daily test from today
    case get_todays_daily_test(user_id) do
      nil ->
        generate_daily_test(user_id)

      existing_test ->
        # Ensure test_steps are loaded
        existing_test = Repo.preload(existing_test, :test_steps)
        {:ok, existing_test}
    end
  end

  @doc """
  Generates a new daily test for a user.

  Combines SRS due reviews with new words to create a comprehensive
  daily review test.

  ## Examples

      iex> generate_daily_test(user_id)
      {:ok, %Test{}}

  """
  def generate_daily_test(user_id) do
    # Get due reviews
    due_reviews = Learning.get_due_reviews(user_id, limit: @daily_goal)

    # Calculate how many new words to add
    due_count = length(due_reviews)
    new_words_needed = max(0, @daily_goal - due_count)
    new_words_needed = min(new_words_needed, @new_word_limit)

    # Get new words for learning
    new_words =
      if new_words_needed > 0 do
        get_eligible_new_words(user_id, limit: new_words_needed)
      else
        []
      end

    # Combine and create test items
    test_items = build_test_items(due_reviews, new_words, [])

    if test_items == [] do
      {:error, :no_items_available}
    else
      create_daily_test(user_id, test_items)
    end
  end

  @doc """
  Checks if a user has already completed their daily test today.

  ## Examples

      iex> daily_test_completed_today?(user_id)
      true

  """
  alias Medoru.Tests.TestSession

  def daily_test_completed_today?(user_id) do
    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00])
    end_of_day = DateTime.new!(today, ~T[23:59:59])

    TestSession
    |> join(:inner, [ts], t in assoc(ts, :test))
    |> where([ts, t], ts.user_id == ^user_id and t.test_type == :daily)
    |> where([ts], ts.status == :completed)
    |> where([ts], ts.completed_at >= ^beginning_of_day and ts.completed_at <= ^end_of_day)
    |> Repo.exists?()
  end

  @doc """
  Gets today's daily test for a user if one exists.

  ## Examples

      iex> get_todays_daily_test(user_id)
      %Test{}

  """
  def get_todays_daily_test(user_id) do
    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00])
    end_of_day = DateTime.new!(today, ~T[23:59:59])

    Test
    |> where([t], t.test_type == :daily and t.creator_id == ^user_id)
    |> where([t], t.inserted_at >= ^beginning_of_day and t.inserted_at <= ^end_of_day)
    |> where([t], t.status in [:published, :ready])
    |> preload(:test_steps)
    |> order_by([t], desc: t.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Archives old daily tests for a user, keeping only today's.

  ## Examples

      iex> archive_old_daily_tests(user_id)
      {:ok, %{archived: 5}}

  """
  def archive_old_daily_tests(user_id) do
    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00])

    old_tests =
      Test
      |> where([t], t.test_type == :daily and t.creator_id == ^user_id)
      |> where([t], t.inserted_at < ^beginning_of_day)
      |> where([t], t.status != :archived)
      |> Repo.all()

    archived_count =
      Enum.reduce(old_tests, 0, fn test, count ->
        case Tests.archive_test(test) do
          {:ok, _} -> count + 1
          {:error, _} -> count
        end
      end)

    {:ok, %{archived: archived_count}}
  end

  # Private functions

  # Get new words that are available for the daily test
  # Includes words the user has learned (in UserProgress)
  # but hasn't reviewed yet (no ReviewSchedule or not due)
  defp get_eligible_new_words(user_id, opts) do
    limit = Keyword.get(opts, :limit, 5)

    # Get words from UserProgress without ReviewSchedule
    # These are words that have been learned but not yet scheduled for review
    user_progress_entries = Medoru.Learning.get_new_words_for_review(user_id, limit: limit)

    # Map to words - no additional filtering needed
    # If a word is in UserProgress, it means the user has learned it
    Enum.map(user_progress_entries, & &1.word)
  end

  # Build test items from reviews and new words
  defp build_test_items(due_reviews, new_words, _started_lesson_ids) do
    # Create items from due reviews
    review_items =
      Enum.map(due_reviews, fn progress ->
        word = progress.word

        %{
          word: word,
          user_progress: progress,
          is_new: false,
          question_types: [:meaning_to_reading, :reading_to_meaning]
        }
      end)

    # Create items from new words
    new_items =
      Enum.map(new_words, fn word ->
        %{
          word: word,
          user_progress: nil,
          is_new: true,
          question_types: [:meaning_to_reading, :reading_to_meaning]
        }
      end)

    # Combine and shuffle
    (review_items ++ new_items) |> Enum.shuffle()
  end

  # Create the daily test with steps
  defp create_daily_test(user_id, test_items) do
    # Archive old daily tests first
    archive_old_daily_tests(user_id)

    # Create the test
    test_attrs = %{
      title: "Daily Review - #{Date.utc_today()}",
      description:
        "Daily review with #{length(test_items)} words (#{count_reviews(test_items)} reviews, #{count_new(test_items)} new)",
      test_type: :daily,
      status: :published,
      is_system: true,
      creator_id: user_id,
      metadata: %{
        daily_test_date: Date.to_iso8601(Date.utc_today())
      }
    }

    with {:ok, test} <- Tests.create_test(test_attrs),
         {:ok, _steps} <- create_test_steps(test, test_items),
         {:ok, ready_test} <- Tests.ready_test(test) do
      # Preload test_steps before returning
      {:ok, Repo.preload(ready_test, :test_steps)}
    end
  end

  # Create test steps for all test items
  defp create_test_steps(test, test_items) do
    steps =
      test_items
      |> Enum.flat_map(&build_word_steps/1)
      |> Enum.with_index(fn step, index -> Map.put(step, :order_index, index) end)

    Tests.create_test_steps(test, steps)
  end

  # Build steps for a single word (mix of multichoice and reading_text)
  # Randomly assigns question types to create variety
  defp build_word_steps(%{word: word, is_new: is_new}) do
    base_attrs = %{
      word_id: word.id,
      step_type: :vocabulary,
      hints: ["Take your time and think about the word"]
    }

    # Randomly decide which question types to include
    # Options: multichoice meaning, multichoice reading, reading_text (input)
    question_types = select_question_types(is_new)

    Enum.map(question_types, fn
      :word_to_meaning ->
        Map.merge(base_attrs, %{
          question_type: :multichoice,
          question: "What does '#{word.text}' mean?",
          correct_answer: word.meaning,
          points: 1,
          options: fetch_meaning_options(word),
          question_data: %{
            word_text: word.text,
            word_reading: word.reading,
            type: :word_to_meaning,
            is_new_word: is_new
          }
        })

      :word_to_reading ->
        Map.merge(base_attrs, %{
          question_type: :multichoice,
          question: "How do you read '#{word.text}'?",
          correct_answer: word.reading,
          points: 1,
          options: fetch_reading_options(word),
          question_data: %{
            word_text: word.text,
            word_meaning: word.meaning,
            type: :word_to_reading,
            is_new_word: is_new
          }
        })

      :reading_text ->
        Map.merge(base_attrs, %{
          question_type: :reading_text,
          question: "Type the meaning and reading for '#{word.text}'",
          correct_answer: Jason.encode!(%{meaning: word.meaning, reading: word.reading}),
          points: 2,
          options: [],
          hints: ["Type the English meaning and hiragana reading"],
          explanation: "#{word.text} means '#{word.meaning}' and is read as '#{word.reading}'",
          question_data: %{
            type: :reading_text,
            word_text: word.text,
            word_meaning: word.meaning,
            word_reading: word.reading,
            is_new_word: is_new
          }
        })
    end)
  end

  # Select question types for a word
  # New words: 2 multichoice questions (easier)
  # Review words: mix of multichoice and reading_text (more challenging)
  defp select_question_types(is_new) do
    case is_new do
      true ->
        # New words get 2 multichoice questions
        [:word_to_meaning, :word_to_reading]

      false ->
        # Review words get variety:
        # 50%: 1 multichoice + 1 reading_text
        # 50%: 2 multichoice
        if :rand.uniform() > 0.5 do
          [:word_to_meaning, :reading_text]
        else
          [:word_to_reading, :reading_text]
        end
    end
  end

  # Fetch meaning options with distractors
  defp fetch_meaning_options(word) do
    distractors =
      Word
      |> where([w], w.id != ^word.id and w.difficulty == ^word.difficulty)
      |> order_by(fragment("RANDOM()"))
      |> limit(@distractor_count)
      |> select([w], w.meaning)
      |> Repo.all()

    [word.meaning | distractors] |> Enum.shuffle()
  end

  # Fetch reading options with distractors
  defp fetch_reading_options(word) do
    distractors =
      Word
      |> where([w], w.id != ^word.id and w.difficulty == ^word.difficulty)
      |> order_by(fragment("RANDOM()"))
      |> limit(@distractor_count)
      |> select([w], w.reading)
      |> Repo.all()

    [word.reading | distractors] |> Enum.shuffle()
  end

  # Count reviews in test items
  defp count_reviews(items) do
    Enum.count(items, &(!&1.is_new))
  end

  # Count new words in test items
  defp count_new(items) do
    Enum.count(items, & &1.is_new)
  end
end
