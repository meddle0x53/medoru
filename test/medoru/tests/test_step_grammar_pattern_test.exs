defmodule Medoru.Tests.TestStepGrammarPatternTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  alias Medoru.Tests.TestStep
  alias Medoru.Tests.TestStepAnswer

  describe "grammar_pattern question type" do
    test "default points is 10" do
      assert TestStep.default_points(:grammar_pattern) == 10
    end

    test "changeset accepts grammar_pattern as valid question_type" do
      attrs = %{
        order_index: 0,
        step_type: "grammar",
        question_type: "grammar_pattern",
        question: "Build a sentence",
        correct_answer: "山田さんは学生じゃありません。",
        points: 10,
        test_id: Ecto.UUID.generate()
      }

      changeset = TestStep.changeset(%TestStep{}, attrs)
      assert changeset.valid?
    end

    test "changeset rejects wrong points for grammar_pattern" do
      attrs = %{
        order_index: 0,
        step_type: "grammar",
        question_type: "grammar_pattern",
        question: "Build a sentence",
        correct_answer: "test",
        points: 5,
        test_id: Ecto.UUID.generate()
      }

      changeset = TestStep.changeset(%TestStep{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:points]
    end

    test "validate_answer compares strings for grammar_pattern" do
      assert TestStepAnswer.validate_answer(
        "山田さんは学生じゃありません。",
        "山田さんは学生じゃありません。",
        %{}
      )

      refute TestStepAnswer.validate_answer(
        "wrong answer",
        "山田さんは学生じゃありません。",
        %{}
      )
    end

    test "validate_answer accepts alternative correct answers" do
      assert TestStepAnswer.validate_answer(
        "山田さんは学生です。",
        "山田さんは学生じゃありません。",
        %{"alt_correct_answers" => ["山田さんは学生です。"]}
      )
    end

    test "normalize_answer handles Japanese whitespace" do
      assert TestStepAnswer.validate_answer(
        "  山田さんは学生じゃありません。  ",
        "山田さんは学生じゃありません。",
        %{}
      )
    end

    test "creates grammar_pattern step via Tests context" do
      user = user_fixture_with_registration()
      test_record = test_fixture(%{created_by_id: user.id, status: :draft})

      attrs = %{
        "order_index" => 0,
        "step_type" => "grammar",
        "question_type" => "grammar_pattern",
        "question" => "Build a sentence following the example",
        "points" => 10,
        "correct_answer" => "山田さんは学生じゃありません。",
        "question_data" => %{
          "example" => "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。",
          "words" => "山田さん / 学生",
          "alt_correct_answers" => ["山田さんは学生です。"]
        }
      }

      assert {:ok, step} = Medoru.Tests.create_test_step(test_record, attrs)
      assert step.question_type == :grammar_pattern
      assert step.correct_answer == "山田さんは学生じゃありません。"
      assert step.question_data["example"] == "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"
    end
  end
end
