defmodule Medoru.Tests.CustomLessonTestGenerator do
  @moduledoc """
  Generates tests for custom lessons created by teachers.

  Similar to LessonTestGenerator but adapted for custom lessons:
  - Uses words from the custom lesson
  - Configurable: with or without writing steps
  - Distractors come from the same lesson words
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Content.CustomLesson
  alias Medoru.Tests

  # Question types to generate per word
  @step_types [
    :meaning_to_word,
    :reading_to_word,
    :word_to_meaning,
    :word_to_reading,
    :image_to_meaning
  ]

  @doc """
  Generates or updates a test for a custom lesson.

  ## Options
    * `:include_writing` - Include kanji writing steps (default: false)
    * `:steps_per_word` - Number of steps to generate per word (default: 3)
    * `:distractor_count` - Number of wrong options per question (default: 3)

  ## Examples

      iex> generate_lesson_test(lesson_id)
      {:ok, %Test{}}

      iex> generate_lesson_test(lesson_id, include_writing: true)
      {:ok, %Test{}}

  """
  def generate_lesson_test(lesson_id, opts \\ []) do
    include_writing = Keyword.get(opts, :include_writing, false)
    steps_per_word = Keyword.get(opts, :steps_per_word, 3)
    distractor_count = Keyword.get(opts, :distractor_count, 3)

    # Get lesson with words and their kanji
    lesson =
      CustomLesson
      |> where([l], l.id == ^lesson_id)
      |> preload(custom_lesson_words: [word: [word_kanjis: :kanji]])
      |> Repo.one!()

    words = Enum.map(lesson.custom_lesson_words, & &1.word)

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
        is_system: true,
        creator_id: lesson.creator_id
      }

      with {:ok, test} <- Tests.create_test(test_attrs),
           {:ok, _steps} <-
             generate_steps(test, words, steps_per_word, distractor_count, include_writing),
           {:ok, updated_test} <- Tests.ready_test(test) do
        # Update lesson with test reference
        lesson
        |> Ecto.Changeset.change(test_id: test.id)
        |> Repo.update()

        {:ok, updated_test}
      end
    end
  end

  # Generates test steps for all words
  defp generate_steps(test, words, steps_per_word, distractor_count, include_writing) do
    # Get distractor pool: words from the same lesson
    distractor_pool = words

    # Generate writing steps if enabled
    writing_steps =
      if include_writing do
        generate_writing_steps(words)
      else
        []
      end

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
        kanji_id: kanji.id,
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
    # Limit to available types if word count is low
    selected_types = Enum.take_random(@step_types, min(steps_per_word, length(@step_types)))

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
        image_path: word.image_path
      }
    }
  end

  # Add distractor options to a step
  defp add_distractors(step, correct_word, distractor_count, distractor_pool) do
    # Check if this is an image question
    is_image_question = get_in(step, [:question_data, :type]) == :image_to_meaning

    if is_image_question do
      add_image_distractors(step, correct_word, distractor_count, distractor_pool)
    else
      {distractors, distractor_ids} =
        fetch_distractors(correct_word, distractor_count, step, distractor_pool)

      # Create pairs of {option, word_id} and shuffle together to maintain alignment
      pairs =
        [{step.correct_answer, correct_word.id} | Enum.zip(distractors, distractor_ids)]
        |> Enum.shuffle()

      # Unzip the pairs back into separate lists
      {options, option_word_ids} = Enum.unzip(pairs)

      # Ensure question_data exists before adding option_word_ids and options
      # Store both options (text) and option_word_ids for locale-aware validation
      question_data = Map.get(step, :question_data) || %{}

      step
      |> Map.put(:options, options)
      |> Map.put(
        :question_data,
        Map.merge(question_data, %{
          option_word_ids: option_word_ids,
          options: options
        })
      )
    end
  end

  # Add image-based distractors for image_to_meaning questions
  defp add_image_distractors(step, correct_word, distractor_count, distractor_pool) do
    # Fetch distractor words that have images
    {distractor_images, distractor_ids} =
      fetch_image_distractors(correct_word, distractor_count, distractor_pool)

    # Check if we have enough image distractors and the correct word has an image
    has_enough_images =
      correct_word.image_path != nil and length(distractor_images) >= distractor_count

    unless has_enough_images do
      # Not enough images - convert to regular word_to_meaning question
      question_data =
        step
        |> Map.get(:question_data, %{})
        |> Map.put(:type, :word_to_meaning)
        |> Map.put(:fallback_from_image, true)

      # Fetch regular text distractors
      {distractors, fallback_ids} =
        fetch_distractors(correct_word, distractor_count, step, distractor_pool)

      # Create pairs and shuffle
      pairs =
        [{step.correct_answer, correct_word.id} | Enum.zip(distractors, fallback_ids)]
        |> Enum.shuffle()

      {options, option_word_ids} = Enum.unzip(pairs)

      step
      |> Map.put(:options, options)
      |> Map.put(
        :question_data,
        Map.merge(question_data, %{
          option_word_ids: option_word_ids,
          options: options
        })
      )
    else
      # Build image options for distractors
      distractor_image_data =
        Enum.zip(distractor_images, distractor_ids)
        |> Enum.map(fn {word, id} ->
          %{
            "image_path" => word.image_path,
            "word_id" => id,
            "word_text" => word.text
          }
        end)

      # Build correct answer image data
      correct_image = %{
        "image_path" => correct_word.image_path,
        "word_id" => correct_word.id,
        "word_text" => correct_word.text
      }

      # Get meanings for options (text answers)
      distractor_meanings = Enum.map(distractor_images, & &1.meaning)

      # Create pairs of {meaning, word_id} and shuffle
      pairs =
        [{step.correct_answer, correct_word.id} | Enum.zip(distractor_meanings, distractor_ids)]
        |> Enum.shuffle()

      {shuffled_meanings, shuffled_ids} = Enum.unzip(pairs)

      # Also shuffle image options
      shuffled_images = [correct_image | distractor_image_data] |> Enum.shuffle()

      # Get existing question_data and merge
      question_data =
        Map.get(step, :question_data, %{})
        |> Map.merge(%{
          image_options: shuffled_images,
          option_word_ids: shuffled_ids,
          options: shuffled_meanings
        })

      step
      |> Map.put(:options, shuffled_meanings)
      |> Map.put(:question_data, question_data)
    end
  end

  # Fetch distractor words with images for image questions
  defp fetch_image_distractors(correct_word, count, distractor_pool) do
    # Get words with images, excluding the correct word
    pool_with_images =
      distractor_pool
      |> Enum.reject(&(&1.id == correct_word.id))
      |> Enum.filter(& &1.image_path)
      |> Enum.take(count)

    ids = Enum.map(pool_with_images, & &1.id)
    {pool_with_images, ids}
  end

  # Fetch distractor words based on step type
  # Returns {distractor_values, distractor_word_ids}
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

    # Get distractors from the pool (excluding the correct word)
    # Keep word_ids for meaning-based questions to enable localization
    pool_distractors =
      distractor_pool
      |> Enum.reject(&(&1.id == correct_word.id))
      |> Enum.take(count)

    values = Enum.map(pool_distractors, &Map.get(&1, distractor_field))
    ids = Enum.map(pool_distractors, & &1.id)

    # If we don't have enough from the pool, supplement with generic distractors
    if length(values) >= count do
      {Enum.take(values, count), Enum.take(ids, count)}
    else
      needed = count - length(values)
      additional_values = generate_generic_distractors(needed, distractor_field)
      # Generic distractors don't have word_ids, use nil
      additional_ids = List.duplicate(nil, needed)
      {values ++ additional_values, ids ++ additional_ids}
    end
  end

  # Generate generic distractors when pool is insufficient
  defp generate_generic_distractors(count, :meaning) do
    generic = ["to do something", "something", "place", "person", "time", "action", "object"]
    Enum.take(generic, count)
  end

  defp generate_generic_distractors(count, :text) do
    generic = ["あ", "い", "う", "え", "お", "か", "き", "く", "け", "こ"]
    Enum.take(generic, count)
  end

  defp generate_generic_distractors(count, :reading) do
    generic = ["ああ", "いい", "うう", "ええ", "おお", "かか", "きき", "くく"]
    Enum.take(generic, count)
  end

  # Helper functions for Japanese character detection
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
end
