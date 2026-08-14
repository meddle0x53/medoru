defmodule Medoru.Tests.TestStepAnswerTest do
  use Medoru.DataCase

  alias Medoru.Tests.TestStepAnswer

  describe "normalize_answer/1" do
    test "normalizes binary answers" do
      assert TestStepAnswer.normalize_answer("  Hello World  ") == "hello world"
      assert TestStepAnswer.normalize_answer("UPPERCASE") == "uppercase"
      assert TestStepAnswer.normalize_answer("  multiple   spaces  ") == "multiple spaces"
    end

    test "handles nil answers" do
      assert TestStepAnswer.normalize_answer(nil) == ""
    end

    test "converts non-binary values to string" do
      assert TestStepAnswer.normalize_answer(123) == "123"
      assert TestStepAnswer.normalize_answer(:atom) == "atom"
      assert TestStepAnswer.normalize_answer(true) == "true"
    end

    test "handles empty string" do
      assert TestStepAnswer.normalize_answer("") == ""
    end
  end

  describe "answer_changeset/4" do
    test "validates correct answer" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 0
      }

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_correct) == true
      assert Ecto.Changeset.get_field(changeset, :points_earned) == 10
    end

    test "validates incorrect answer" do
      attrs = %{
        "answer" => "wrong",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 0
      }

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_correct) == false
      assert Ecto.Changeset.get_field(changeset, :points_earned) == 0
    end

    test "applies penalties for extra attempts" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 3,
        "hints_used" => 0
      }

      # 2 extra attempts * 25% = 50% penalty
      # 10 * 0.5 = 5 points
      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert Ecto.Changeset.get_field(changeset, :points_earned) == 5
    end

    test "applies penalties for hints used" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 2
      }

      # 2 hints * 10% = 20% penalty
      # 10 * 0.8 = 8 points
      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert Ecto.Changeset.get_field(changeset, :points_earned) == 8
    end

    test "halves points for listening hint" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 1
      }

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10, %{}, :listening)

      assert Ecto.Changeset.get_field(changeset, :points_earned) == 5
    end

    test "listening hint with extra attempts caps at 90% penalty" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 3,
        "hints_used" => 1
      }

      # 2 extra attempts * 25% = 50% + listening hint 50% = 100%, capped at 90%
      # 10 * 0.1 = 1 point (also enforced by max(..., 1))
      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10, %{}, :listening)

      assert Ecto.Changeset.get_field(changeset, :points_earned) == 1
    end

    test "minimum points is 1 when correct" do
      attrs = %{
        "answer" => "correct",
        "step_index" => 0,
        "attempts" => 10,
        "hints_used" => 10
      }

      # Maximum penalty is 90%, so at least 1 point
      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert Ecto.Changeset.get_field(changeset, :points_earned) == 1
    end

    test "handles nil answer gracefully" do
      attrs = %{
        "answer" => nil,
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 0
      }

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_correct) == false
      assert Ecto.Changeset.get_field(changeset, :points_earned) == 0
    end

    test "matches alternative correct answers from question_data" do
      attrs = %{
        "answer" => "alternative",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 0
      }

      question_data = %{"alt_correct_answers" => ["alternative", "another"]}

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "correct", 10, question_data)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_correct) == true
      assert Ecto.Changeset.get_field(changeset, :points_earned) == 10
    end

    test "ignores punctuation when comparing answers" do
      attrs = %{
        "answer" => "学生です",
        "step_index" => 0,
        "attempts" => 1,
        "hints_used" => 0
      }

      changeset =
        TestStepAnswer.answer_changeset(%TestStepAnswer{}, attrs, "学生です。", 10)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :is_correct) == true
    end
  end
end
