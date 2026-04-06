defmodule Medoru.Tests.WordSetTestGenerator do
  @moduledoc """
  Generates practice tests for word sets.

  Similar to CustomLessonTestGenerator but:
  - Test type is :practice
  - Uses user-selected step types
  - Random 1 to max_steps questions per word
  - No points awarded (practice mode)
  """

  alias Medoru.Repo
  alias Medoru.Tests

  @doc """
  Generates a practice test for a word set.

  ## Options
    * `:step_types` - List of step type atoms (required)
    * `:max_steps_per_word` - Max questions per word (1-5, default: 3)
    * `:distractor_count` - Number of distractors per question (default: 3)

  ## Examples
      generate_test(word_set, words, step_types: [:word_to_meaning, :word_to_reading], max_steps_per_word: 3)
  """
  def generate_test(word_set, words, opts \\ []) do
    step_types = Keyword.get(opts, :step_types, [:word_to_meaning])
    max_steps_per_word = Keyword.get(opts, :max_steps_per_word, 3)
    distractor_count = Keyword.get(opts, :distractor_count, 3)

    # Validate inputs
    step_types = validate_step_types(step_types)
    max_steps_per_word = clamp(max_steps_per_word, 1, 5)

    # Create test
    test_attrs = %{
      title: "#{word_set.name} - Practice",
      description: "Practice test with #{length(words)} words",
      test_type: :practice,
      status: :published,
      is_system: true,
      creator_id: word_set.user_id,
      metadata: %{
        word_set_id: word_set.id,
        step_types: step_types,
        max_steps_per_word: max_steps_per_word
      }
    }

    with {:ok, test} <- Tests.create_test(test_attrs),
         {:ok, _steps} <-
           generate_steps(test, words, step_types, max_steps_per_word, distractor_count),
         {:ok, ready_test} <- Tests.ready_test(test) do
      # Update word set with test reference
      word_set
      |> Ecto.Changeset.change(practice_test_id: test.id)
      |> Repo.update()

      {:ok, ready_test}
    end
  end

  defp generate_steps(test, words, step_types, max_steps_per_word, distractor_count) do
    # Use words from the set as distractor pool
    distractor_pool = words

    # For each word, generate random number of steps (1 to max_steps_per_word)
    all_steps =
      Enum.flat_map(words, fn word ->
        # Random number of steps for this word (1 to max)
        num_steps = :rand.uniform(max_steps_per_word)

        # Randomly select step types for this word
        selected_types = Enum.take_random(step_types, min(num_steps, length(step_types)))

        selected_types
        |> Enum.map(fn step_type ->
          build_step_data(word, step_type, distractor_count, distractor_pool)
        end)
        |> Enum.reject(&is_nil/1)
      end)

    # Shuffle all steps for random order
    shuffled_steps = Enum.shuffle(all_steps)

    # Assign order indices
    steps_with_order =
      Enum.with_index(shuffled_steps, fn step, index ->
        Map.put(step, :order_index, index)
      end)

    Tests.create_test_steps(test, steps_with_order)
  end

  defp build_step_data(word, :word_to_meaning, distractor_count, distractor_pool) do
    step = %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "#{word.text}",
      correct_answer: word.meaning,
      word_id: word.id,
      # Practice tests don't award points
      points: 0,
      hints: ["Think about the kanji meanings"],
      question_data: %{
        word_text: word.text,
        question_label: "meaning"
      }
    }

    add_distractors(step, word, distractor_count, :meaning, distractor_pool)
  end

  defp build_step_data(word, :word_to_reading, distractor_count, distractor_pool) do
    step = %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "#{word.text}",
      correct_answer: word.reading,
      word_id: word.id,
      points: 0,
      hints: ["Remember the kanji readings"],
      question_data: %{
        word_text: word.text,
        question_label: "reading"
      }
    }

    add_distractors(step, word, distractor_count, :reading, distractor_pool)
  end

  defp build_step_data(word, :reading_text, _distractor_count, _distractor_pool) do
    %{
      step_type: :vocabulary,
      question_type: :reading_text,
      question: "#{word.text}",
      correct_answer: "#{word.meaning}|#{word.reading}",
      word_id: word.id,
      points: 0,
      hints: ["Type the English meaning and hiragana reading"],
      question_data: %{
        word_text: word.text,
        question_label: "reading_text"
      }
    }
  end

  defp build_step_data(word, :image_to_meaning, distractor_count, distractor_pool) do
    step = %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "#{word.text}",
      correct_answer: word.meaning,
      word_id: word.id,
      points: 0,
      hints: ["Look at the image carefully"],
      question_data: %{
        type: :image_to_meaning,
        word_text: word.text,
        word_reading: word.reading,
        image_path: word.image_path
      }
    }

    # For image questions, we need special handling
    add_image_distractors(step, word, distractor_count, distractor_pool)
  end

  defp build_step_data(word, :kanji_writing, _distractor_count, _distractor_pool) do
    # Collect unique kanji from word
    kanji_list = extract_kanji_from_word(word)

    if length(kanji_list) > 0 do
      # Pick one random kanji for writing
      kanji = Enum.random(kanji_list)
      meanings = Enum.join(kanji.meanings || [], ", ")

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
        word_id: word.id,
        points: 0,
        hints: ["Remember the stroke order"],
        question_data: %{
          type: :kanji_writing,
          kanji: kanji.character,
          kanji_id: kanji.id,
          meanings: kanji.meanings,
          stroke_count: kanji.stroke_count,
          strokes: strokes
        }
      }
    else
      # No kanji in this word, skip this step type
      nil
    end
  end

  defp add_distractors(step, word, count, field, distractor_pool)
       when field in [:meaning, :reading] do
    # Get distractors from the word set (not random words)
    # Deduplicate by field value to avoid duplicate options
    distractors =
      distractor_pool
      |> Enum.reject(&(&1.id == word.id))
      |> Enum.uniq_by(&Map.get(&1, field))
      |> Enum.take_random(count)
      |> Enum.map(&Map.get(&1, field))

    # Create pairs and shuffle
    pairs = [
      {step.correct_answer, word.id}
      | Enum.zip(distractors, List.duplicate(nil, length(distractors)))
    ]

    shuffled = Enum.shuffle(pairs)
    {options, option_word_ids} = Enum.unzip(shuffled)

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

  defp add_image_distractors(step, word, count, distractor_pool) do
    # For image questions, fetch words with images from the word set
    distractors =
      distractor_pool
      |> Enum.reject(&(&1.id == word.id))
      |> Enum.filter(& &1.image_path)
      |> Enum.take_random(count)

    distractor_data =
      Enum.map(distractors, fn d ->
        %{
          "image_path" => d.image_path,
          "word_id" => d.id,
          "word_text" => d.text
        }
      end)

    distractor_meanings = Enum.map(distractors, & &1.meaning)
    distractor_ids = Enum.map(distractors, & &1.id)

    # Create pairs and shuffle meanings
    pairs = [{step.correct_answer, word.id} | Enum.zip(distractor_meanings, distractor_ids)]
    {shuffled_meanings, shuffled_ids} = Enum.unzip(Enum.shuffle(pairs))

    # Build correct image data
    correct_image = %{
      "image_path" => word.image_path,
      "word_id" => word.id,
      "word_text" => word.text
    }

    # Shuffle image options
    shuffled_images = [correct_image | distractor_data] |> Enum.shuffle()

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

  defp extract_kanji_from_word(word) do
    case word.word_kanjis do
      %Ecto.Association.NotLoaded{} ->
        # Load word with kanji
        word_with_kanji = Medoru.Content.get_word_with_kanji!(word.id)
        Enum.map(word_with_kanji.word_kanjis, & &1.kanji) |> Enum.reject(&is_nil/1)

      word_kanjis ->
        Enum.map(word_kanjis, & &1.kanji) |> Enum.reject(&is_nil/1)
    end
  end

  defp validate_step_types(types) do
    allowed = [
      :word_to_meaning,
      :word_to_reading,
      :reading_text,
      :image_to_meaning,
      :kanji_writing
    ]

    Enum.filter(types, &(&1 in allowed))
  end

  defp clamp(value, min, max) when is_integer(value) do
    value |> max(min) |> min(max)
  end

  defp clamp(_, min, max), do: div(min + max, 2)
end
