defmodule Medoru.TestsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Tests` context.
  """

  alias Medoru.Tests
  alias Medoru.AccountsFixtures

  @doc """
  Generate a teacher user.
  """
  def teacher_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{type: "teacher"})
    |> AccountsFixtures.user_fixture_with_registration()
  end

  @doc """
  Generate a teacher test (in_progress state).
  """
  def teacher_test_fixture(teacher_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test #{System.unique_integer()}",
        description: "A test description",
        time_limit_seconds: 600,
        setup_state: "in_progress"
      })

    {:ok, test} = Tests.create_teacher_test(attrs, teacher_id)
    test
  end

  @doc """
  Generate a test.
  """
  def test_fixture(attrs \\ %{}) do
    {:ok, test} =
      attrs
      |> Enum.into(%{
        title: "Test #{System.unique_integer()}",
        description: "A test description",
        test_type: :teacher,
        status: :in_progress,
        time_limit_seconds: 600,
        total_points: 10,
        max_attempts: 1
      })
      |> Tests.create_test()

    test
  end

  @doc """
  Generate a test step for a test.
  """
  def test_step_fixture(%Tests.Test{} = test, attrs \\ %{}) do
    question_type = attrs[:question_type] || :multichoice

    # Points depend on question type
    default_points =
      case question_type do
        :multichoice -> 1
        :fill -> 2
        :writing -> 5
        _ -> 1
      end

    attrs =
      Enum.into(attrs, %{
        question: "Sample question?",
        step_type: :vocabulary,
        question_type: :multichoice,
        correct_answer: "Correct",
        options: ["Correct", "Wrong1", "Wrong2", "Wrong3"],
        points: default_points,
        order_index: 0,
        hints: [],
        explanation: nil,
        question_data: %{}
      })

    {:ok, step} = Tests.create_test_step(test, attrs)
    step
  end
end
