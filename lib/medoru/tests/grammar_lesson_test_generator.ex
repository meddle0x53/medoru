defmodule Medoru.Tests.GrammarLessonTestGenerator do
  @moduledoc """
  Generates tests for grammar lessons.

  Each grammar lesson step gets 2 sentence_validation test steps:
  - Steps are shuffled randomly
  - Grammar pattern is hidden
  - Test step title is "<lesson step title> N"
  - Hint is the first example in the lesson step (kanji version)
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Content.CustomLesson
  alias Medoru.Tests

  @doc """
  Generates or updates a test for a grammar lesson.

  ## Examples

      iex> generate_lesson_test(lesson_id)
      {:ok, %Test{}}

  """
  def generate_lesson_test(lesson_id) do
    # Get lesson with grammar steps
    lesson =
      CustomLesson
      |> where([l], l.id == ^lesson_id)
      |> preload(:grammar_lesson_steps)
      |> Repo.one!()

    steps = lesson.grammar_lesson_steps

    if length(steps) == 0 do
      {:error, :no_steps_in_lesson}
    else
      # Archive existing test if present
      if lesson.test_id do
        old_test = Tests.get_test!(lesson.test_id)
        Tests.archive_test(old_test)
      end

      # Create new test
      test_attrs = %{
        title: "#{lesson.title} - Grammar Test",
        description: "Test your understanding of #{length(steps)} grammar patterns",
        test_type: :lesson,
        status: :published,
        is_system: true,
        creator_id: lesson.creator_id
      }

      with {:ok, test} <- Tests.create_test(test_attrs),
           {:ok, _steps} <- generate_steps(test, steps),
           {:ok, updated_test} <- Tests.ready_test(test) do
        # Update lesson with test reference and requires_test flag
        lesson
        |> Ecto.Changeset.change(test_id: test.id, requires_test: true)
        |> Repo.update()

        {:ok, updated_test}
      end
    end
  end

  # Generates test steps for all grammar lesson steps
  defp generate_steps(test, lesson_steps) do
    # For each lesson step, generate 2 sentence_validation steps
    all_steps =
      lesson_steps
      |> Enum.flat_map(fn step ->
        build_sentence_validation_steps(step)
      end)
      |> shuffle_steps()
      |> Enum.with_index(fn step, index -> Map.put(step, :order_index, index) end)

    Tests.create_test_steps(test, all_steps)
  end

  # Build 2 sentence_validation steps for a grammar lesson step
  defp build_sentence_validation_steps(lesson_step) do
    # Get hint from first example (kanji version)
    hint = get_first_example_sentence(lesson_step)

    # Get the pattern for validation
    pattern = lesson_step.pattern_elements || []

    # Generate 2 steps with the same pattern but different titles
    [
      build_step(lesson_step, 1, hint, pattern),
      build_step(lesson_step, 2, hint, pattern)
    ]
  end

  defp build_step(lesson_step, _index, hint, pattern) do
    %{
      step_type: :grammar,
      question_type: :sentence_validation,
      question: lesson_step.title,
      # Validation is pattern-based, not exact match
      correct_answer: "",
      points: 5,
      hints: if(hint, do: [hint], else: []),
      explanation: lesson_step.explanation,
      question_data: %{
        "pattern" => pattern,
        "grammar_step" => true,
        "lesson_step_title" => lesson_step.title,
        # Hide the pattern
        "show_pattern" => false
      },
      options: [],
      max_attempts: 4
    }
  end

  # Get the first example sentence (kanji version) for use as hint
  defp get_first_example_sentence(lesson_step) do
    examples = lesson_step.examples || []

    case List.first(examples) do
      nil -> nil
      example when is_map(example) -> example["sentence"] || example[:sentence]
      _ -> nil
    end
  end

  # Shuffle steps for random order
  defp shuffle_steps(steps) do
    Enum.shuffle(steps)
  end
end
