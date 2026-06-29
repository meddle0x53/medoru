defmodule Medoru.Tests.ClassroomVocabularyTestGenerator do
  @moduledoc """
  Generates a teacher test for a classroom from selected vocabulary-lesson words.

  The resulting test is published directly to the classroom so students can take it
  through the normal classroom test flow.
  """

  alias Medoru.Classrooms
  alias Medoru.Repo
  alias Medoru.Tests
  alias Medoru.Tests.TestStepBuilder

  @allowed_step_types [
    :word_to_meaning,
    :word_to_reading,
    :reading_text,
    :image_to_meaning,
    :kanji_writing
  ]

  @doc """
  Generates and publishes a vocabulary test for a classroom.

  ## Options
    * `:step_types` - List of step type atoms (default: [:word_to_meaning])
    * `:max_times_per_word` - How many times a single word may appear (1-3, default: 1)
    * `:total_questions` - Exact number of questions in the test (default: all possible)
    * `:title` - Test title (default: derived from classroom name)
    * `:distractor_count` - Number of distractors per multichoice question (default: 3)
    * `:due_date` - Optional due date for the classroom publication
    * `:max_attempts` - Optional max attempts for the classroom publication

  ## Examples
      generate_test(classroom, words, teacher_id,
        step_types: [:word_to_meaning, :word_to_reading],
        max_times_per_word: 2,
        total_questions: 30,
        title: "N5 Review"
      )
  """
  def generate_test(classroom, words, teacher_id, opts \\ []) do
    step_types = Keyword.get(opts, :step_types, [:word_to_meaning])
    max_times_per_word = Keyword.get(opts, :max_times_per_word, 1)
    total_questions = Keyword.get(opts, :total_questions)
    title = Keyword.get(opts, :title, default_title(classroom))
    distractor_count = Keyword.get(opts, :distractor_count, 3)
    due_date = Keyword.get(opts, :due_date)
    max_attempts = Keyword.get(opts, :max_attempts)

    step_types = validate_step_types(step_types)
    max_times_per_word = clamp(max_times_per_word, 1, 3)

    if length(words) == 0 do
      {:error, :no_words_selected}
    else
      step_types = filter_step_types(step_types, words)

      candidate_pairs = build_candidate_pairs(words, step_types, max_times_per_word)

      total_questions =
        case total_questions do
          nil -> length(candidate_pairs)
          n when is_integer(n) and n > 0 -> min(n, length(candidate_pairs))
          _ -> length(candidate_pairs)
        end

      if total_questions == 0 do
        {:error, :no_questions_possible}
      else
        selected_pairs = Enum.take_random(candidate_pairs, total_questions)

        Repo.transaction(fn ->
          test_attrs = %{
            title: title,
            description: "Vocabulary test with #{length(selected_pairs)} questions",
            test_type: :teacher,
            status: :published,
            setup_state: "published",
            is_system: true,
            creator_id: teacher_id,
            metadata: %{
              step_types: step_types,
              max_times_per_word: max_times_per_word,
              total_questions: total_questions,
              word_count: length(words)
            }
          }

          with {:ok, test} <- Tests.create_test(test_attrs),
               {:ok, _steps} <-
                 create_steps(test, selected_pairs, words, distractor_count),
               {:ok, _classroom_test} <-
                 Classrooms.publish_test_to_classroom(classroom.id, test.id, teacher_id, %{
                   due_date: due_date,
                   max_attempts: max_attempts
                 }),
               updated_test <- Repo.get!(Tests.Test, test.id) do
            updated_test
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
      end
    end
  end

  defp build_candidate_pairs(words, step_types, max_times_per_word) do
    words
    |> Enum.with_index()
    |> Enum.flat_map(fn {word, word_index} ->
      available_types = available_types_for_word(word, step_types)

      # A word may appear at most max_times_per_word times in total across all
      # selected question types. Cycle through the available types with a
      # per-word offset so different words are assigned different question
      # types, ensuring variety when multiple types are selected.
      if available_types == [] do
        []
      else
        available_types
        |> Stream.cycle()
        |> Stream.drop(word_index)
        |> Enum.take(max_times_per_word)
        |> Enum.map(fn type -> {word, type} end)
      end
    end)
  end

  defp available_types_for_word(word, step_types) do
    has_image? = not is_nil(word.image_path)
    has_kanji? = TestStepBuilder.word_has_kanji?(word)

    Enum.reject(step_types, fn type ->
      case type do
        :word_to_reading -> only_kana?(word.text)
        :reading_to_word -> only_kana?(word.text)
        :image_to_meaning -> not has_image?
        :kanji_writing -> not has_kanji?
        _ -> false
      end
    end)
  end

  defp filter_step_types(step_types, words) do
    words_with_images = Enum.filter(words, & &1.image_path)

    if :image_to_meaning in step_types and length(words_with_images) < 4 do
      Enum.reject(step_types, &(&1 == :image_to_meaning))
    else
      step_types
    end
  end

  defp create_steps(test, selected_pairs, words, distractor_count) do
    words_with_images = Enum.filter(words, & &1.image_path)

    steps =
      selected_pairs
      |> Enum.shuffle()
      |> Enum.map(fn {word, step_type} ->
        pool = if step_type == :image_to_meaning, do: words_with_images, else: words

        build_step(word, step_type, distractor_count, pool)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.with_index(fn step, index -> Map.put(step, :order_index, index) end)

    Tests.create_test_steps(test, steps)
  end

  defp build_step(word, :word_to_meaning, distractor_count, distractor_pool) do
    step = base_step(word, 1)

    TestStepBuilder.add_distractors(step, word, distractor_count, distractor_pool,
      field: :meaning
    )
  end

  defp build_step(word, :word_to_reading, distractor_count, distractor_pool) do
    step =
      base_step(word, 1)
      |> Map.put(:correct_answer, word.reading)
      |> put_in([:question_data, :question_label], "reading")
      |> put_in([:question_data, :word_meaning], word.meaning)

    TestStepBuilder.add_distractors(step, word, distractor_count, distractor_pool,
      field: :reading
    )
  end

  defp build_step(word, :reading_text, _distractor_count, _distractor_pool) do
    base_step(word, 2)
    |> Map.merge(%{
      step_type: :vocabulary,
      question_type: :reading_text,
      correct_answer:
        Jason.encode!(%{
          meaning: word.meaning,
          reading: word.reading
        }),
      hints: ["Type the English meaning and hiragana reading"],
      question_data: %{
        word_text: word.text,
        word_reading: word.reading,
        word_meaning: word.meaning,
        question_label: "reading_text",
        is_kana_only: only_kana?(word.text)
      }
    })
  end

  defp build_step(word, :image_to_meaning, _distractor_count, _distractor_pool)
       when is_nil(word.image_path) do
    nil
  end

  defp build_step(word, :image_to_meaning, distractor_count, distractor_pool) do
    step =
      base_step(word, 1)
      |> Map.merge(%{
        question_type: :image_to_meaning,
        correct_answer: word.meaning,
        hints: ["Look at the image carefully"],
        question_data: %{
          type: :image_to_meaning,
          word_text: word.text,
          word_reading: word.reading,
          image_path: word.image_path
        }
      })

    add_image_distractors(step, word, distractor_count, distractor_pool)
  end

  defp build_step(word, :kanji_writing, _distractor_count, _distractor_pool) do
    kanji_list = TestStepBuilder.extract_kanji_from_word(word)

    if length(kanji_list) > 0 do
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
        points: 5,
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
      nil
    end
  end

  defp base_step(word, points) do
    %{
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "#{word.text}",
      correct_answer: word.meaning,
      word_id: word.id,
      points: points,
      hints: ["Think about the kanji meanings"],
      question_data: %{
        word_text: word.text,
        word_reading: word.reading,
        question_label: "meaning"
      }
    }
  end

  defp add_image_distractors(step, word, count, distractor_pool) do
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

    pairs = [{step.correct_answer, word.id} | Enum.zip(distractor_meanings, distractor_ids)]
    {shuffled_meanings, shuffled_ids} = Enum.unzip(Enum.shuffle(pairs))

    correct_image = %{
      "image_path" => word.image_path,
      "word_id" => word.id,
      "word_text" => word.text
    }

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

  defp default_title(classroom) do
    "#{classroom.name} - Vocabulary Test"
  end

  defp validate_step_types(types) do
    Enum.filter(types, &(&1 in @allowed_step_types))
  end

  defp clamp(value, min, max) when is_integer(value) do
    value |> max(min) |> min(max)
  end

  defp clamp(_, min, max), do: div(min + max, 2)

  defp only_kana?(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> Enum.all?(&kana_char?/1)
  end

  defp kana_char?(codepoint) do
    (codepoint >= 0x3040 and codepoint <= 0x309F) or
      (codepoint >= 0x30A0 and codepoint <= 0x30FF) or
      (codepoint >= 0xFF65 and codepoint <= 0xFF9F)
  end
end
