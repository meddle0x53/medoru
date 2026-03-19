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

  # Question types to generate per word
  @step_types [
    :meaning_to_word,
    :reading_to_word,
    :word_to_meaning,
    :word_to_reading,
    :reading_text
  ]

  @doc """
  Generates or updates a test for a lesson.

  If the lesson already has a test, it will be archived and a new one created.

  ## Options
    * `:steps_per_word` - Number of steps to generate per word (default: 3)
    * `:distractor_count` - Number of wrong options per question (default: 3)

  ## Examples

      iex> generate_lesson_test(lesson_id)
      {:ok, %Test{}}

      iex> generate_lesson_test(lesson_id, steps_per_word: 4)
      {:ok, %Test{}}

  """
  def generate_lesson_test(lesson_id, opts \\ []) do
    steps_per_word = Keyword.get(opts, :steps_per_word, 3)
    distractor_count = Keyword.get(opts, :distractor_count, 3)

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
             generate_steps(test, words, steps_per_word, distractor_count, lesson.id),
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
  defp generate_steps(test, words, steps_per_word, distractor_count, lesson_id) do
    # Get unique kanji from all words for writing steps
    writing_steps = generate_writing_steps(words)

    # Get distractor pool: same lesson + previous lessons
    # Pass lesson_id only - we'll filter current word per-step
    distractor_pool = build_distractor_pool(lesson_id, words)

    # For each word, generate multichoice steps and flatten
    multichoice_steps =
      words
      |> Enum.flat_map(fn word ->
        word
        |> generate_word_steps(steps_per_word)
        |> Enum.map(fn step ->
          add_distractors(step, word, distractor_count, distractor_pool)
        end)
      end)

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
      |> Enum.flat_map(&get_word_kanji/1)
      |> Enum.uniq_by(& &1.id)

    # Create a writing step for each unique kanji
    Enum.map(unique_kanji, &build_writing_step/1)
  end

  # Get kanji characters from a word
  defp get_word_kanji(word) do
    # Ensure word_kanjis is loaded
    word_kanjis =
      case word.word_kanjis do
        %Ecto.Association.NotLoaded{} ->
          # Fallback: load the word with kanji
          word_with_kanji = Medoru.Content.get_word_with_kanji!(word.id)
          word_with_kanji.word_kanjis

        word_kanjis ->
          word_kanjis
      end

    # Extract unique kanji
    word_kanjis
    |> Enum.map(& &1.kanji)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
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

  # Generate steps for a single word
  defp generate_word_steps(word, steps_per_word) do
    # Select random step types for this word
    selected_types = Enum.take_random(@step_types, steps_per_word)

    Enum.map(selected_types, fn step_type ->
      build_step_data(word, step_type)
    end)
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
      hints: ["Think about the kanji meanings"]
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
      hints: ["Listen to the pronunciation in your head"]
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
      hints: ["Break down the kanji meanings"]
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
      hints: ["Remember the kanji readings"]
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

  # Add distractor options to a step
  defp add_distractors(step, correct_word, distractor_count, distractor_pool) do
    distractors = fetch_distractors(correct_word, distractor_count, step, distractor_pool)
    # Shuffle options so correct answer isn't always in same position
    options = [step.correct_answer | distractors] |> Enum.shuffle()

    Map.put(step, :options, options)
  end

  # Fetch distractor words based on step type
  # Priority: 1) Same lesson words, 2) Previous lesson words, 3) Generic fallback
  # Randomly samples from the pool to ensure variety across questions
  defp fetch_distractors(
         correct_word,
         count,
         %{correct_answer: correct_answer},
         distractor_pool
       ) do
    # Determine what type of distractors we need based on correct_answer
    distractor_field =
      cond do
        contains_japanese?(correct_answer) ->
          if only_kana?(correct_answer), do: :reading, else: :text

        true ->
          :meaning
      end

    # Get distractors from the pool - randomly sample for variety
    # Filter out the correct word first, then shuffle and take random sample
    pool_distractors =
      distractor_pool
      |> Enum.reject(&(&1.id == correct_word.id))
      |> Enum.shuffle()
      |> Enum.take(count)
      |> Enum.map(&Map.get(&1, distractor_field))
      |> Enum.reject(&is_nil/1)

    # If we have enough from the pool, use them
    if length(pool_distractors) >= count do
      Enum.take(pool_distractors, count)
    else
      # Otherwise, supplement with words from same difficulty (but not in current curriculum)
      needed = count - length(pool_distractors)

      existing_ids = [correct_word.id | Enum.map(distractor_pool, & &1.id)]

      additional_distractors =
        Word
        |> where([w], w.id not in ^existing_ids and w.difficulty == ^correct_word.difficulty)
        |> where([w], not is_nil(field(w, ^distractor_field)))
        |> limit(^needed)
        |> order_by(fragment("RANDOM()"))
        |> select([w], field(w, ^distractor_field))
        |> Repo.all()

      all_distractors = pool_distractors ++ additional_distractors
      pad_distractors(all_distractors, count, distractor_field)
    end
  end

  # Pad with generic distractors if not enough found
  defp pad_distractors(distractors, count, _field) when length(distractors) >= count do
    Enum.take(distractors, count)
  end

  defp pad_distractors(distractors, count, :meaning) do
    generic = ["to do something", "something", "place", "person", "time", "action", "object"]
    distractors ++ Enum.take(generic, count - length(distractors))
  end

  defp pad_distractors(distractors, count, :text) do
    generic = ["あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ"]
    distractors ++ Enum.take(generic, count - length(distractors))
  end

  defp pad_distractors(distractors, count, :reading) do
    generic = ["ああ", "いい", "うう", "ええ", "おお", "かか", "きき", "くく"]
    distractors ++ Enum.take(generic, count - length(distractors))
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
