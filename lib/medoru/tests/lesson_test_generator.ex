defmodule Medoru.Tests.LessonTestGenerator do
  @moduledoc """
  Generates tests for lessons based on the words in the lesson.

  Each word in the lesson gets 3-4 multichoice test steps:
  - Meaning step: Show word, select meaning
  - Reading step: Show word, select reading
  - Reverse meaning: Show meaning, select word
  - Reverse reading: Show reading, select word

  Steps are randomized and the test is associated with the lesson.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Content.{Lesson, LessonWord, Word}
  alias Medoru.Tests
  alias Medoru.Tests.TestStepBuilder

  # Mapping from user preference strings to internal step types
  @preference_to_type %{
    "word_to_meaning" => :word_to_meaning,
    "word_to_reading" => :word_to_reading,
    "reading_text" => :reading_text,
    "image_to_meaning" => :image_to_meaning,
    "kanji_writing" => :kanji_writing
  }

  @doc """
  Generates or updates a test for a lesson.

  If the lesson already has a test, it will be archived and a new one created.

  ## Options
    * `:steps_per_word` - Number of steps to generate per word (default: 3)
    * `:distractor_count` - Number of wrong options per question (default: 3)
    * `:user_preferences` - List of preferred step types from user profile (e.g., ["word_to_meaning", "reading_text"])

  ## Examples

      iex> generate_lesson_test(lesson_id)
      {:ok, %Test{}}

      iex> generate_lesson_test(lesson_id, steps_per_word: 4)
      {:ok, %Test{}}

      iex> generate_lesson_test(lesson_id, user_preferences: ["word_to_meaning", "kanji_writing"])
      {:ok, %Test{}}

  """
  def generate_lesson_test(lesson_id, opts \\ []) do
    steps_per_word = Keyword.get(opts, :steps_per_word, 3)
    distractor_count = Keyword.get(opts, :distractor_count, 3)
    user_preferences = Keyword.get(opts, :user_preferences)

    # Get lesson with words and their kanji
    lesson =
      Lesson
      |> where([l], l.id == ^lesson_id)
      |> preload(lesson_words: [word: [word_kanjis: :kanji]])
      |> Repo.one!()

    words = Enum.map(lesson.lesson_words, & &1.word)

    if length(words) == 0 do
      {:error, :no_words_in_lesson}
    else
      # Archive existing test if present
      if lesson.test_id do
        old_test = Tests.get_test!(lesson.test_id)
        Tests.archive_test(old_test)
      end

      # Create new test
      test_attrs = %{
        title: "#{lesson.title} - Test",
        description: "Test your knowledge of the #{length(words)} words in this lesson",
        test_type: :lesson,
        status: :published,
        lesson_id: lesson.id,
        is_system: true
      }

      with {:ok, test} <- Tests.create_test(test_attrs),
           {:ok, _steps} <-
             generate_steps(
               test,
               words,
               steps_per_word,
               distractor_count,
               lesson.id,
               user_preferences
             ),
           {:ok, updated_test} <- Tests.ready_test(test) do
        # Update lesson with test reference
        lesson
        |> Ecto.Changeset.change(test_id: test.id)
        |> Repo.update()

        {:ok, updated_test}
      end
    end
  end

  @doc """
  Gets or creates a test for a lesson. If the lesson already has a published test,
  returns that one. Otherwise generates a new test.

  ## Examples

      iex> get_or_create_lesson_test(lesson_id)
      {:ok, %Test{}}

  """
  def get_or_create_lesson_test(lesson_id, opts \\ []) do
    lesson =
      Lesson
      |> where([l], l.id == ^lesson_id)
      |> preload([:test])
      |> Repo.one!()

    case lesson.test do
      %{status: status} = existing_test when status in [:published, :ready] ->
        {:ok, existing_test}

      _ ->
        generate_lesson_test(lesson_id, opts)
    end
  end

  # Generates test steps for all words
  defp generate_steps(test, words, steps_per_word, distractor_count, lesson_id, user_preferences) do
    # Get distractor pool: same lesson + previous lessons
    distractor_pool = build_distractor_pool(lesson_id, words)

    # Build list of available step types from user preferences or defaults
    available_types = get_available_step_types(user_preferences)

    # Separate multichoice types from writing (handled separately)
    multichoice_types = Enum.reject(available_types, &(&1 == :kanji_writing))

    # For each word, generate random number of steps (1 to steps_per_word)
    multichoice_steps =
      words
      |> Enum.flat_map(fn word ->
        num_steps = :rand.uniform(steps_per_word)

        selected_types =
          Enum.take_random(multichoice_types, min(num_steps, length(multichoice_types)))

        selected_types
        |> Enum.map(fn step_type ->
          build_step_data(word, step_type)
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn step ->
          add_distractors(step, word, distractor_count, distractor_pool)
        end)
      end)

    # Generate writing steps separately if kanji_writing is in user preferences
    writing_steps =
      if :kanji_writing in available_types do
        generate_writing_steps(words)
      else
        []
      end

    # Combine all steps, shuffle, and assign order indices
    all_steps =
      (writing_steps ++ multichoice_steps)
      |> shuffle_steps()
      |> Enum.with_index(fn step, index -> Map.put(step, :order_index, index) end)

    Tests.create_test_steps(test, all_steps)
  end

  # Build a prioritized distractor pool:
  # Priority 1: Words from the same lesson (most confusing)
  # Priority 2: Words from previous lessons (already learned)
  # We NEVER use words from future lessons (unlearned) as distractors
  defp build_distractor_pool(nil, _words), do: []

  defp build_distractor_pool(lesson_id, current_words) do
    current_word_ids = Enum.map(current_words, & &1.id)

    # Get current lesson info
    lesson = Repo.get(Lesson, lesson_id)

    if lesson do
      # Same lesson words (highest priority - most confusing)
      # Include ALL words from same lesson - the correct word will be filtered per-step
      # Randomize to ensure variety across test regenerations
      same_lesson_words =
        LessonWord
        |> where([lw], lw.lesson_id == ^lesson_id)
        |> preload(:word)
        |> order_by(fragment("RANDOM()"))
        |> limit(20)
        |> Repo.all()
        |> Enum.map(& &1.word)

      # Previous lessons words (already learned)
      # Exclude current lesson words to avoid duplicates
      # Randomize to ensure variety across test regenerations
      previous_lesson_words =
        LessonWord
        |> join(:inner, [lw], l in Lesson, on: lw.lesson_id == l.id)
        |> where(
          [lw, l],
          l.difficulty == ^lesson.difficulty and l.order_index < ^lesson.order_index
        )
        |> where([lw], lw.word_id not in ^current_word_ids)
        |> preload(:word)
        |> order_by(fragment("RANDOM()"))
        |> limit(30)
        |> Repo.all()
        |> Enum.map(& &1.word)

      # Note: We intentionally do NOT use words from future lessons (next lessons)
      # as distractors because they haven't been learned yet.
      # Combine in priority order: same lesson first, then previous lessons
      same_lesson_words ++ previous_lesson_words
    else
      []
    end
  end

  # Generate writing steps for unique kanji in lesson words
  defp generate_writing_steps(words) do
    # Collect all unique kanji from words
    unique_kanji =
      words
      |> Enum.flat_map(&TestStepBuilder.extract_kanji_from_word/1)
      |> Enum.uniq_by(& &1.id)

    # Create a writing step for each unique kanji
    Enum.map(unique_kanji, &build_writing_step/1)
  end

  # Build a writing step for a kanji
  defp build_writing_step(kanji) do
    meanings = Enum.join(kanji.meanings || [], ", ")

    # Extract stroke paths from kanji.stroke_data
    strokes =
      case kanji.stroke_data do
        %{"strokes" => s} when is_list(s) -> s
        _ -> []
      end

    %{
      step_type: :writing,
      question_type: :writing,
      question: "__MSG_WRITE_KANJI_FOR__|#{meanings}",
      correct_answer: kanji.character,
      kanji_id: kanji.id,
      points: 5,
      hints: ["Remember the stroke order", "Start from top-left"],
      explanation: "The kanji '#{kanji.character}' means #{meanings}",
      question_data: %{
        type: :kanji_writing,
        kanji: kanji.character,
        meanings: kanji.meanings,
        stroke_count: kanji.stroke_count,
        strokes: strokes
      },
      # Writing steps don't have multiple choice options
      options: []
    }
  end

  # Get available step types based on user preferences
  # If no preferences, use all types except image_to_meaning and kanji_writing (require special handling)
  defp get_available_step_types(nil) do
    # Default: exclude image_to_meaning and kanji_writing as they require special handling/fallbacks
    [:meaning_to_word, :reading_to_word, :word_to_meaning, :word_to_reading, :reading_text]
  end

  defp get_available_step_types(preferences) when is_list(preferences) do
    # Map user preference strings to internal types
    preferences
    |> Enum.map(&Map.get(@preference_to_type, &1))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> get_available_step_types(nil)
      types -> types
    end
  end

  # Build step data based on step type
  defp build_step_data(word, :meaning_to_word) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "__MSG_WHICH_WORD_MEANS__|#{word.meaning}",
      correct_answer: word.text,
      word_id: word.id,
      points: 1,
      hints: ["Think about the kanji meanings"],
      question_data: %{
        type: :meaning_to_word,
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning
      }
    }
  end

  defp build_step_data(word, :reading_to_word) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "__MSG_WHICH_WORD_IS_READ__|#{word.reading}",
      correct_answer: word.text,
      word_id: word.id,
      points: 1,
      hints: ["Listen to the pronunciation in your head"],
      question_data: %{
        type: :reading_to_word,
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning
      }
    }
  end

  defp build_step_data(word, :word_to_meaning) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "__MSG_WHAT_DOES_WORD_MEAN__|#{word.text}",
      correct_answer: word.meaning,
      word_id: word.id,
      points: 1,
      hints: ["Break down the kanji meanings"],
      question_data: %{
        type: :word_to_meaning,
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning
      }
    }
  end

  defp build_step_data(word, :word_to_reading) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "__MSG_HOW_DO_YOU_READ__|#{word.text}",
      correct_answer: word.reading,
      word_id: word.id,
      points: 1,
      hints: ["Remember the kanji readings"],
      question_data: %{
        type: :word_to_reading,
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning
      }
    }
  end

  defp build_step_data(word, :reading_text) do
    %{
      step_type: :reading,
      question_type: :reading_text,
      question: "__MSG_TYPE_MEANING_AND_READING__|#{word.text}",
      correct_answer: Jason.encode!(%{meaning: word.meaning, reading: word.reading}),
      word_id: word.id,
      points: 2,
      hints: ["Think about the kanji meanings and their readings"],
      explanation: "#{word.text} means '#{word.meaning}' and is read as '#{word.reading}'",
      question_data: %{
        type: :reading_text,
        word_text: word.text,
        word_meaning: word.meaning,
        word_reading: word.reading
      },
      # Reading text steps don't have multiple choice options
      options: []
    }
  end

  defp build_step_data(word, :image_to_meaning) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "__MSG_WHAT_DOES_WORD_MEAN__|#{word.text}",
      correct_answer: word.meaning,
      word_id: word.id,
      points: 1,
      hints: ["Look at the image carefully"],
      question_data: %{
        type: :image_to_meaning,
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning,
        image_path: word.image_path
      }
    }
  end

  # Add distractor options to a step
  defp add_distractors(step, correct_word, distractor_count, distractor_pool) do
    # Check if this is an image-based question
    is_image_question = get_in(step, [:question_data, :type]) == :image_to_meaning

    if is_image_question do
      add_image_distractors(step, correct_word, distractor_count, distractor_pool)
    else
      field = distractor_field_for_step(step)

      TestStepBuilder.add_distractors(step, correct_word, distractor_count, distractor_pool,
        field: field,
        deduplicate: true
      )
    end
  end

  defp distractor_field_for_step(%{correct_answer: answer}) do
    cond do
      contains_japanese?(answer) ->
        if only_kana?(answer), do: :reading, else: :text

      true ->
        :meaning
    end
  end

  # Add image-based distractors for image_to_meaning questions
  defp add_image_distractors(step, correct_word, distractor_count, distractor_pool) do
    # Fetch distractor words that have images
    {distractor_images, distractor_ids} =
      fetch_image_distractors(correct_word, distractor_count, distractor_pool)

    # Check if the correct word has an image AND we have enough image distractors
    correct_word_has_image = correct_word.image_path != nil

    if not correct_word_has_image or length(distractor_images) < distractor_count do
      # Not enough images - convert to regular word_to_meaning question
      question_data =
        step
        |> Map.get(:question_data, %{})
        |> Map.put(:type, :word_to_meaning)
        |> Map.put(:fallback_from_image, true)

      # Fetch regular text distractors using shared logic
      step = %{step | question_data: question_data}

      TestStepBuilder.add_distractors(step, correct_word, distractor_count, distractor_pool,
        field: :meaning,
        deduplicate: true
      )
    else
      # Build image options with correct answer first
      correct_image = %{meaning: step.correct_answer, image_path: correct_word.image_path}
      _all_images = [correct_image | distractor_images]

      # Shuffle images and track positions using pair-based shuffling
      pairs = [{correct_image, correct_word.id} | Enum.zip(distractor_images, distractor_ids)]
      shuffled = Enum.shuffle(pairs)
      {shuffled_images, shuffled_ids} = Enum.unzip(shuffled)
      shuffled_meanings = Enum.map(shuffled_images, & &1.meaning)

      question_data =
        step
        |> Map.get(:question_data, %{})
        |> Map.put(:image_options, shuffled_images)
        |> Map.put(:option_word_ids, shuffled_ids)
        |> Map.put(:options, shuffled_meanings)

      step
      |> Map.put(:options, shuffled_meanings)
      |> Map.put(:question_data, question_data)
    end
  end

  # Fetch distractor words with images
  defp fetch_image_distractors(correct_word, count, distractor_pool) do
    # Filter pool for words with images
    words_with_images =
      distractor_pool
      |> Enum.reject(&(&1.id == correct_word.id))
      |> Enum.filter(& &1.image_path)
      |> Enum.shuffle()
      |> Enum.take(count)

    images = Enum.map(words_with_images, &%{meaning: &1.meaning, image_path: &1.image_path})
    ids = Enum.map(words_with_images, & &1.id)

    # If not enough from pool, try to get more from database
    if length(images) < count do
      needed = count - length(images)
      existing_ids = [correct_word.id | Enum.map(distractor_pool, & &1.id)]

      additional_words =
        Word
        |> where([w], w.id not in ^existing_ids and w.difficulty == ^correct_word.difficulty)
        |> where([w], not is_nil(w.image_path))
        |> limit(^needed)
        |> order_by(fragment("RANDOM()"))
        |> Repo.all()

      additional_images =
        Enum.map(additional_words, &%{meaning: &1.meaning, image_path: &1.image_path})

      additional_ids = Enum.map(additional_words, & &1.id)

      {images ++ additional_images, ids ++ additional_ids}
    else
      {images, ids}
    end
  end

  # Helper functions for Japanese character detection
  # CJK Unified Ideographs: U+4E00 to U+9FFF
  # Hiragana: U+3040 to U+309F
  # Katakana: U+30A0 to U+30FF

  defp contains_japanese?(string) do
    string
    |> String.to_charlist()
    |> Enum.any?(&japanese_char?/1)
  end

  defp japanese_char?(codepoint) do
    # CJK Unified Ideographs (Kanji)
    # Hiragana
    # Katakana
    # CJK Unified Ideographs Extension A
    # Full-width ASCII
    # Half-width Katakana
    (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
      (codepoint >= 0x3040 and codepoint <= 0x309F) or
      (codepoint >= 0x30A0 and codepoint <= 0x30FF) or
      (codepoint >= 0x3400 and codepoint <= 0x4DBF) or
      (codepoint >= 0xFF01 and codepoint <= 0xFF5E) or
      (codepoint >= 0xFF65 and codepoint <= 0xFF9F)
  end

  defp only_kana?(string) do
    string
    |> String.to_charlist()
    |> Enum.all?(&kana_char?/1)
  end

  defp kana_char?(codepoint) do
    # Hiragana only
    # Katakana only
    # Half-width Katakana
    (codepoint >= 0x3040 and codepoint <= 0x309F) or
      (codepoint >= 0x30A0 and codepoint <= 0x30FF) or
      (codepoint >= 0xFF65 and codepoint <= 0xFF9F)
  end

  # Shuffle steps for random order
  defp shuffle_steps(steps) do
    Enum.shuffle(steps)
  end

  @doc """
  Regenerates tests for all lessons that don't have one.
  Useful for backfilling after this feature is deployed.

  ## Options
    * `:batch_size` - Number of lessons to process at once (default: 100)

  ## Examples

      iex> generate_missing_lesson_tests()
      {:ok, %{created: 50, failed: 0}}

  """
  def generate_missing_lesson_tests(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 100)

    # Get lessons without tests that have words
    lessons =
      Lesson
      |> where([l], is_nil(l.test_id))
      |> join(:inner, [l], lw in assoc(l, :lesson_words))
      |> distinct([l], l.id)
      |> limit(^batch_size)
      |> Repo.all()

    results =
      Enum.reduce(lessons, %{created: 0, failed: 0, errors: []}, fn lesson, acc ->
        case generate_lesson_test(lesson.id) do
          {:ok, _test} ->
            %{acc | created: acc.created + 1}

          {:error, reason} ->
            %{
              acc
              | failed: acc.failed + 1,
                errors: [{lesson.id, reason} | acc.errors]
            }
        end
      end)

    {:ok, results}
  end
end
