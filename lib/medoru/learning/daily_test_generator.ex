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
  # Base daily goal - will scale with user's learned words
  @base_daily_goal 10
  @max_daily_goal 25
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
    # Calculate dynamic daily goal based on user's learned words
    learned_count = count_learned_words(user_id)
    daily_goal = calculate_daily_goal(learned_count)

    # Get due reviews
    due_reviews = Learning.get_due_reviews(user_id, limit: daily_goal)

    # Get unique word IDs from due reviews to exclude from new words
    due_word_ids = Enum.map(due_reviews, & &1.word_id)

    # Calculate how many new words to add
    due_count = length(due_reviews)
    new_words_needed = max(0, daily_goal - due_count)
    new_words_needed = min(new_words_needed, @new_word_limit)

    # Get new words for learning (excluding words already in due reviews)
    new_words =
      if new_words_needed > 0 do
        get_eligible_new_words(user_id, limit: new_words_needed, exclude_word_ids: due_word_ids)
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

  @doc """
  Deletes today's daily test for a user.
  This allows the user to generate a fresh daily test.
  Only admins should use this function.

  ## Examples

      iex> delete_todays_daily_test(user_id)
      {:ok, :deleted}

      iex> delete_todays_daily_test(user_id_without_test)
      {:ok, :no_test_found}

  """
  def delete_todays_daily_test(user_id) do
    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00])
    end_of_day = DateTime.new!(today, ~T[23:59:59])

    # Find today's daily test
    test =
      Test
      |> where([t], t.test_type == :daily and t.creator_id == ^user_id)
      |> where([t], t.inserted_at >= ^beginning_of_day and t.inserted_at <= ^end_of_day)
      |> limit(1)
      |> Repo.one()

    case test do
      nil ->
        {:ok, :no_test_found}

      %Test{id: test_id} ->
        # Use Ecto.UUID.cast to ensure proper binary format
        {:ok, test_id_binary} = Ecto.UUID.cast(test_id)

        # Delete test steps using proper query
        Repo.delete_all(
          from(ts in "test_steps", where: ts.test_id == type(^test_id_binary, :binary_id))
        )

        # Delete test sessions
        Repo.delete_all(
          from(s in "test_sessions", where: s.test_id == type(^test_id_binary, :binary_id))
        )

        # Delete the test
        Repo.delete(test)

        {:ok, :deleted}
    end
  end

  # Private functions

  # Count how many words the user has learned
  defp count_learned_words(user_id) do
    Learning.count_learned_words(user_id)
  end

  # Calculate daily goal based on learned words count
  # Scales from @base_daily_goal to @max_daily_goal
  defp calculate_daily_goal(learned_count) do
    cond do
      learned_count < 20 -> @base_daily_goal
      learned_count < 50 -> 15
      learned_count < 100 -> 20
      true -> @max_daily_goal
    end
  end

  # Get words for daily test, prioritized by mastery level
  # Words with lower mastery levels are prioritized
  defp get_eligible_new_words(user_id, opts) do
    limit = Keyword.get(opts, :limit, 5)
    exclude_ids = Keyword.get(opts, :exclude_word_ids, [])

    # Use the new priority-based function that orders by mastery level
    Learning.get_words_for_daily_test(user_id, limit: limit, exclude_word_ids: exclude_ids)
  end

  # Build test items from reviews and new words
  defp build_test_items(due_reviews, new_word_progress, _started_lesson_ids) do
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

    # Get word IDs from review items to exclude from new items
    review_word_ids = MapSet.new(due_reviews, & &1.word_id)

    # Create items from new words (now passed as UserProgress entries)
    # Filter out any words already in due reviews
    new_items =
      new_word_progress
      |> Enum.reject(fn progress -> MapSet.member?(review_word_ids, progress.word_id) end)
      |> Enum.map(fn progress ->
        %{
          word: progress.word,
          user_progress: progress,
          is_new: progress.mastery_level == 1,
          question_types: [:meaning_to_reading, :reading_to_meaning]
        }
      end)

    # Combine - prioritize lower mastery levels, don't shuffle
    # Items are already ordered by mastery level from the query
    review_items ++ new_items
  end

  # Create the daily test with steps
  defp create_daily_test(user_id, test_items) do
    # Validate test_items is not empty
    if test_items == [] do
      {:error, :no_items_available}
    else
      # Archive old daily tests first
      archive_old_daily_tests(user_id)

      # Get user preferences for daily test step types
      user_step_types = get_user_step_types(user_id)

      # Pre-validate that steps will be generated
      steps_count =
        test_items
        |> Enum.flat_map(&build_word_steps(&1, user_step_types, user_id))
        |> Enum.shuffle()
        |> length()

      if steps_count == 0 do
        {:error, :no_questions_generated}
      else
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
             {:ok, _steps} <- create_test_steps(test, test_items, user_step_types, user_id),
             {:ok, ready_test} <- Tests.ready_test(test) do
          # Preload test_steps before returning
          {:ok, Repo.preload(ready_test, :test_steps)}
        end
      end
    end
  end

  # Get user's preferred step types for daily tests
  defp get_user_step_types(user_id) do
    alias Medoru.Accounts.UserProfile

    UserProfile
    |> where([p], p.user_id == ^user_id)
    |> select([p], p.daily_test_step_types)
    |> Repo.one()
    |> case do
      nil -> nil
      types when is_list(types) -> types
      _ -> nil
    end
  end

  # Create test steps for all test items
  defp create_test_steps(test, test_items, user_step_types, user_id) do
    steps =
      test_items
      |> Enum.flat_map(&build_word_steps(&1, user_step_types, user_id))
      # Shuffle to avoid having all questions for the same word consecutively
      |> Enum.shuffle()
      |> Enum.with_index(fn step, index -> Map.put(step, :order_index, index) end)

    # Validate that we have at least one step
    if steps == [] do
      {:error, :no_questions_generated}
    else
      Tests.create_test_steps(test, steps)
    end
  end

  # Build steps for a single word (mix of multichoice and reading_text)
  # Uses user preferences if available, otherwise random variety
  defp build_word_steps(%{word: word, is_new: is_new}, user_step_types, user_id) do
    base_attrs = %{
      word_id: word.id,
      step_type: :vocabulary,
      hints: ["Take your time and think about the word"]
    }

    # Use user preferences or default selection
    question_types = select_question_types(is_new, user_step_types)

    Enum.map(question_types, fn
      "word_to_meaning" ->
        Map.merge(base_attrs, %{
          question_type: :multichoice,
          question: "__MSG_WHAT_DOES_WORD_MEAN__|#{word.text}",
          correct_answer: word.meaning,
          points: 1,
          options: fetch_meaning_options(word, user_id),
          question_data: %{
            word_text: word.text,
            word_reading: word.reading,
            type: :word_to_meaning,
            is_new_word: is_new
          }
        })

      "word_to_reading" ->
        Map.merge(base_attrs, %{
          question_type: :multichoice,
          question: "__MSG_HOW_DO_YOU_READ__|#{word.text}",
          correct_answer: word.reading,
          points: 1,
          options: fetch_reading_options(word, user_id),
          question_data: %{
            word_text: word.text,
            word_meaning: word.meaning,
            type: :word_to_reading,
            is_new_word: is_new
          }
        })

      "reading_text" ->
        Map.merge(base_attrs, %{
          question_type: :reading_text,
          question: "__MSG_TYPE_MEANING_READING__|#{word.text}",
          correct_answer: Jason.encode!(%{meaning: word.meaning, reading: word.reading}),
          points: 2,
          options: [],
          hints: ["__MSG_TYPE_ENGLISH_HIRAGANA__"],
          explanation: "__MSG_WORD_MEANS_READING__|#{word.text}|#{word.meaning}|#{word.reading}",
          question_data: %{
            type: :reading_text,
            word_text: word.text,
            word_meaning: word.meaning,
            word_reading: word.reading,
            is_new_word: is_new
          }
        })

      "image_to_meaning" ->
        # Try to get image-based options, fallback to text if not enough
        case fetch_image_options(word, user_id) do
          {:ok, options} ->
            Map.merge(base_attrs, %{
              question_type: :multichoice,
              question: "__MSG_WHAT_DOES_WORD_MEAN__|#{word.text}",
              correct_answer: word.meaning,
              points: 1,
              options: Enum.map(options, & &1.meaning),
              question_data: %{
                word_text: word.text,
                word_reading: word.reading,
                type: :image_to_meaning,
                is_new_word: is_new,
                image_options:
                  Enum.map(options, &%{meaning: &1.meaning, image_path: &1.image_path})
              }
            })

          {:error, :not_enough_images} ->
            # Fallback to text-based meaning question
            Map.merge(base_attrs, %{
              question_type: :multichoice,
              question: "__MSG_WHAT_DOES_WORD_MEAN__|#{word.text}",
              correct_answer: word.meaning,
              points: 1,
              options: fetch_meaning_options(word, user_id),
              question_data: %{
                word_text: word.text,
                word_reading: word.reading,
                type: :word_to_meaning,
                is_new_word: is_new,
                fallback_from_image: true
              }
            })
        end

      "kanji_writing" ->
        # Try to build a writing step from the word's kanji
        case build_writing_step_for_word(word) do
          {:ok, step_attrs} ->
            Map.merge(base_attrs, step_attrs)

          {:error, :no_kanji} ->
            # Fallback to word_to_reading if no kanji
            Map.merge(base_attrs, %{
              question_type: :multichoice,
              question: "__MSG_HOW_DO_YOU_READ__|#{word.text}",
              correct_answer: word.reading,
              points: 1,
              options: fetch_reading_options(word, user_id),
              question_data: %{
                word_text: word.text,
                word_meaning: word.meaning,
                type: :word_to_reading,
                is_new_word: is_new,
                fallback_from_writing: true
              }
            })
        end
    end)
  end

  # Build a writing step for a word using its first kanji
  defp build_writing_step_for_word(word) do
    # Ensure word_kanjis is loaded
    word_with_kanji =
      case word.word_kanjis do
        %Ecto.Association.NotLoaded{} ->
          Medoru.Content.get_word_with_kanji!(word.id)

        _ ->
          word
      end

    # Get first kanji with stroke data
    kanji =
      word_with_kanji.word_kanjis
      |> Enum.map(& &1.kanji)
      |> Enum.reject(&is_nil/1)
      |> Enum.find(&has_stroke_data?/1)

    case kanji do
      nil ->
        {:error, :no_kanji}

      kanji ->
        meanings = Enum.join(kanji.meanings || [], ", ")

        # Extract stroke paths from kanji.stroke_data
        strokes =
          case kanji.stroke_data do
            %{"strokes" => s} when is_list(s) -> s
            _ -> []
          end

        {:ok,
         %{
           step_type: :writing,
           question_type: :writing,
           question: "__MSG_WRITE_KANJI_FOR__|#{meanings}",
           correct_answer: kanji.character,
           kanji_id: kanji.id,
           points: 3,
           hints: ["Remember the stroke order", "Start from top-left"],
           explanation: "The kanji '#{kanji.character}' means #{meanings}",
           question_data: %{
             type: :kanji_writing,
             kanji: kanji.character,
             meanings: kanji.meanings,
             stroke_count: kanji.stroke_count,
             strokes: strokes
           },
           options: []
         }}
    end
  end

  # Check if kanji has stroke data for writing practice
  defp has_stroke_data?(kanji) do
    case kanji.stroke_data do
      %{"strokes" => strokes} when is_list(strokes) and length(strokes) > 0 -> true
      _ -> false
    end
  end

  # Select question types for a word based on user preferences
  # If no preferences set, use defaults
  defp select_question_types(_is_new, user_step_types) when is_list(user_step_types) do
    # Filter to only valid types and ensure at least one
    valid_types = [
      "word_to_meaning",
      "word_to_reading",
      "reading_text",
      "image_to_meaning",
      "kanji_writing"
    ]

    # Remove duplicates while preserving order, then filter to valid types
    types =
      user_step_types
      |> Enum.uniq()
      |> Enum.filter(&(&1 in valid_types))

    if types == [] do
      ["word_to_meaning", "word_to_reading"]
    else
      # Randomly select 2 different types if available
      types
      |> Enum.shuffle()
      |> Enum.take(2)
    end
  end

  defp select_question_types(is_new, nil) do
    case is_new do
      true ->
        # New words get 2 multichoice questions
        ["word_to_meaning", "word_to_reading"]

      false ->
        # Review words get variety:
        # 50%: 1 multichoice + 1 reading_text
        # 50%: 2 multichoice
        if :rand.uniform() > 0.5 do
          ["word_to_meaning", "reading_text"]
        else
          ["word_to_reading", "reading_text"]
        end
    end
  end

  # Fetch meaning options with distractors
  # Only uses words the user has learned (has UserProgress for)
  # Does NOT filter by difficulty - any learned word can be a distractor
  defp fetch_meaning_options(word, user_id) do
    distractors =
      Word
      |> join(:inner, [w], up in Learning.UserProgress,
        on: up.word_id == w.id and up.user_id == ^user_id
      )
      |> where([w], w.id != ^word.id)
      |> order_by(fragment("RANDOM()"))
      |> limit(@distractor_count)
      |> select([w], w.meaning)
      |> Repo.all()

    # Ensure correct answer is only added once
    options = [word.meaning | distractors]
    options |> Enum.uniq() |> Enum.shuffle()
  end

  # Fetch reading options with distractors
  # Only uses words the user has learned (has UserProgress for)
  # Does NOT filter by difficulty - any learned word can be a distractor
  defp fetch_reading_options(word, user_id) do
    distractors =
      Word
      |> join(:inner, [w], up in Learning.UserProgress,
        on: up.word_id == w.id and up.user_id == ^user_id
      )
      |> where([w], w.id != ^word.id)
      |> order_by(fragment("RANDOM()"))
      |> limit(@distractor_count)
      |> select([w], w.reading)
      |> Repo.all()

    # Ensure correct answer is only added once
    options = [word.reading | distractors]
    options |> Enum.uniq() |> Enum.shuffle()
  end

  # Fetch image options with distractors
  # Returns {:ok, [%{meaning: ..., image_path: ...}, ...]} or {:error, :not_enough_images}
  # Only uses words the user has learned (has UserProgress for)
  # Does NOT filter by difficulty - any learned word can be a distractor
  defp fetch_image_options(word, user_id) do
    # Check if the target word has an image
    target_word = Word |> where([w], w.id == ^word.id and not is_nil(w.image_path)) |> Repo.one()

    if is_nil(target_word) do
      {:error, :not_enough_images}
    else
      # Get distractors that have images - only from learned words
      distractors =
        Word
        |> join(:inner, [w], up in Learning.UserProgress,
          on: up.word_id == w.id and up.user_id == ^user_id
        )
        |> where([w], w.id != ^word.id)
        |> where([w], not is_nil(w.image_path))
        |> order_by(fragment("RANDOM()"))
        |> limit(@distractor_count)
        |> select([w], %{meaning: w.meaning, image_path: w.image_path})
        |> Repo.all()

      # Need at least 3 distractors + 1 correct = 4 total
      if length(distractors) < @distractor_count do
        {:error, :not_enough_images}
      else
        correct_option = %{meaning: word.meaning, image_path: word.image_path}
        options = [correct_option | distractors]
        # Ensure no duplicates and shuffle
        {:ok, options |> Enum.uniq_by(& &1.meaning) |> Enum.shuffle()}
      end
    end
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
