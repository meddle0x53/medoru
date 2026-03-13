defmodule Medoru.Tests.LessonTestSessionMixedKeysTest do
  @moduledoc """
  Test to verify LessonTestSession works correctly after the mixed keys fix.

  When the bug existed, LessonTestSession used atom keys in attrs map, but
  Tests.record_step_answer/3 added string keys, causing Ecto.CastError.

  After fix: Should return {:correct, _} or {:wrong_answer, _} successfully.
  """
  use Medoru.DataCase

  alias Medoru.Tests
  alias Medoru.Tests.LessonTestSession
  alias Medoru.Content

  describe "lesson test session submit_answer works correctly" do
    setup do
      # Create a user
      user = Medoru.AccountsFixtures.user_fixture()

      # Create a lesson with words
      {:ok, lesson} =
        Content.create_lesson(%{
          title: "Test Lesson",
          description: "For testing mixed keys fix",
          difficulty: 5,
          order_index: 1
        })

      # Create a word
      {:ok, word} =
        Content.create_word(%{
          text: "日本",
          meaning: "Japan",
          reading: "にほん",
          difficulty: 5
        })

      # Create a test for the lesson
      {:ok, test_record} =
        Tests.create_test(%{
          title: "Test Lesson Test",
          test_type: :lesson,
          lesson_id: lesson.id,
          total_points: 1
        })

      # Create a test step
      {:ok, step} =
        Tests.create_test_step(test_record, %{
          order_index: 0,
          step_type: :vocabulary,
          question_type: :multichoice,
          question: "What is the meaning of 日本?",
          correct_answer: "Japan",
          options: ["Japan", "China", "Korea", "USA"],
          points: 1,
          word_id: word.id
        })

      %{user: user, lesson: lesson, test_record: test_record, step: step}
    end

    test "submit_answer succeeds without CastError", %{
      user: user,
      test_record: test_record,
      step: step
    } do
      # Start a lesson test session
      {:ok, %{session: session}} = LessonTestSession.start_lesson_test(user.id, test_record.id)

      # This should succeed without raising Ecto.CastError
      # If the mixed keys bug exists, this will raise:
      # (Ecto.CastError) expected params to be a map with atoms or string keys, 
      # got a map with mixed keys: %{:time_spent_seconds => 10, :answer => "Japan", 
      # :step_index => 0, "test_session_id" => "...", "test_step_id" => "..."}
      #
      # The bug was in LessonTestSession.submit_answer/4 using atom keys:
      #   attrs = %{
      #     answer: answer,
      #     time_spent_seconds: time_spent,
      #     step_index: answer_counter
      #   }
      #
      # While Tests.record_step_answer/3 added string keys:
      #   attrs =
      #     attrs
      #     |> Map.put("test_session_id", session_id)
      #     |> Map.put("test_step_id", step_id)

      # If the mixed keys bug exists, this will raise Ecto.CastError
      # If fixed, it will return successfully
      result =
        LessonTestSession.submit_answer(session.id, step.id, "Japan", time_spent_seconds: 10)

      # Verify it returns a valid response tuple
      assert is_tuple(result)
      assert elem(result, 0) in [:correct, :completed, :incorrect]
    end

    test "submit_writing_answer succeeds without CastError", %{
      user: user,
      test_record: test_record
    } do
      # Create a writing step
      {:ok, writing_step} =
        Tests.create_test_step(test_record, %{
          order_index: 1,
          step_type: :vocabulary,
          question_type: :writing,
          question: "Draw the kanji for 日",
          correct_answer: "日",
          points: 5
        })

      {:ok, %{session: session}} = LessonTestSession.start_lesson_test(user.id, test_record.id)

      # Writing step submission should also work without mixed keys error
      # Note: submit_writing_answer expects strokes data as 3rd arg, is_correct in opts
      result =
        LessonTestSession.submit_writing_answer(
          session.id,
          writing_step.id,
          [],
          time_spent_seconds: 15,
          is_correct: true
        )

      # Verify it returns a valid response tuple
      assert is_tuple(result)
      assert elem(result, 0) in [:correct, :completed, :incorrect]
    end
  end
end
