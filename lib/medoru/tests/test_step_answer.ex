defmodule Medoru.Tests.TestStepAnswer do
  @moduledoc """
  Schema for Test Step Answers - tracks a user's answer to an individual test step.

  Tracks:
  - The answer given
  - Whether it was correct
  - Time taken to answer
  - Number of attempts/hints used
  - Points earned
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "test_step_answers" do
    field :step_index, :integer
    field :answer, :string
    field :is_correct, :boolean
    field :points_earned, :integer, default: 0
    field :time_spent_seconds, :integer, default: 0
    field :attempts, :integer, default: 1
    field :hints_used, :integer, default: 0
    field :answered_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :test_session, Medoru.Tests.TestSession
    belongs_to :test_step, Medoru.Tests.TestStep

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test_step_answer, attrs) do
    test_step_answer
    |> cast(attrs, [
      :step_index,
      :answer,
      :is_correct,
      :points_earned,
      :time_spent_seconds,
      :attempts,
      :hints_used,
      :answered_at,
      :metadata,
      :test_session_id,
      :test_step_id
    ])
    |> validate_required([
      :step_index,
      :is_correct,
      :test_session_id,
      :test_step_id
    ])
    # :answer is intentionally not required — skipped/given-up questions are
    # recorded with an empty answer string so they appear in results review.
    |> validate_length(:answer, max: 5000)
    |> validate_number(:step_index, greater_than_or_equal_to: 0)
    |> validate_number(:points_earned, greater_than_or_equal_to: 0)
    |> validate_number(:time_spent_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:attempts, greater_than_or_equal_to: 1)
    |> validate_number(:hints_used, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:test_session_id)
    |> foreign_key_constraint(:test_step_id)
    |> unique_constraint([:test_session_id, :step_index])
  end

  @doc """
  Changeset for recording an answer to a test step.
  """
  def answer_changeset(
        test_step_answer,
        attrs,
        correct_answer,
        max_points,
        question_data \\ %{},
        step_question_type \\ nil
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      test_step_answer
      |> cast(attrs, [
        :step_index,
        :answer,
        :time_spent_seconds,
        :attempts,
        :hints_used,
        :test_session_id,
        :test_step_id
      ])
      |> put_change(:answered_at, now)

    # Determine if answer is correct and calculate points
    answer = get_field(changeset, :answer)
    attempts = get_field(changeset, :attempts) || 1
    hints_used = get_field(changeset, :hints_used) || 0

    if step_question_type == :grammar_make_question_answer do
      {is_correct, points_earned} =
        grade_make_question_answer(answer, question_data, max_points, attempts, hints_used)

      changeset
      |> put_change(:is_correct, is_correct)
      |> put_change(:points_earned, points_earned)
    else
      # Check if we should use word_id-based validation (for localized content)
      is_correct = validate_answer(answer, correct_answer, question_data)

      # Calculate points with penalties
      points_earned =
        if is_correct do
          apply_penalties(max_points, attempts, hints_used, step_question_type)
        else
          0
        end

      changeset
      |> put_change(:is_correct, is_correct)
      |> put_change(:points_earned, points_earned)
    end
  end

  @doc """
  Separator joining the student's question and answer into the recorded
  answer string for `:grammar_make_question_answer` steps.
  """
  def make_question_answer_separator, do: "\n"

  @doc """
  Builds the answer string submitted for a `:grammar_make_question_answer` step.
  """
  def build_make_question_answer(question, answer) do
    (question || "") <> make_question_answer_separator() <> (answer || "")
  end

  @doc """
  Grades a "make a question and answer it" submission.

  The recorded answer is the student's question and answer joined by
  `make_question_answer_separator/0`. Both parts are converted to kana-only
  readings (`Medoru.Grammar.ReadingConverter.normalize_for_comparison/1`)
  and compared with the expected readings. Full points only when both match;
  half points (rounded down) when exactly one matches.

  Returns `{is_correct, points_earned}`.
  """
  def grade_make_question_answer(
        answer,
        question_data,
        max_points,
        attempts \\ 1,
        hints_used \\ 0
      ) do
    alias Medoru.Grammar.ReadingConverter

    {student_question, student_answer} = split_make_question_answer(answer)

    expected_question_reading =
      question_data["expected_question_reading"] ||
        question_data[:expected_question_reading] ||
        ""

    expected_answer_reading =
      question_data["expected_answer_reading"] ||
        question_data[:expected_answer_reading] ||
        ""

    question_correct =
      ReadingConverter.normalize_for_comparison(student_question) ==
        ReadingConverter.normalize_for_comparison(expected_question_reading)

    answer_correct =
      ReadingConverter.normalize_for_comparison(student_answer) ==
        ReadingConverter.normalize_for_comparison(expected_answer_reading)

    case {question_correct, answer_correct} do
      {true, true} ->
        {true, apply_penalties(max_points, attempts, hints_used, :grammar_make_question_answer)}

      {false, false} ->
        {false, 0}

      _ ->
        # Partial credit: half points rounded down when only one part matches.
        {false, div(max_points, 2)}
    end
  end

  @doc """
  Splits a recorded `:grammar_make_question_answer` answer into its question
  and answer parts.
  """
  def split_make_question_answer(answer) when is_binary(answer) do
    case String.split(answer, make_question_answer_separator(), parts: 2) do
      [question, answer_part] -> {question, answer_part}
      [question] -> {question, ""}
    end
  end

  def split_make_question_answer(_), do: {"", ""}

  @doc """
  Validates an answer, using word_id comparison when option_word_ids are available.
  This fixes the locale mismatch issue where stored correct_answer is in English
  but the student sees and selects a translated option.
  """
  def validate_answer(answer, correct_answer, question_data) do
    option_word_ids = question_data["option_word_ids"] || question_data[:option_word_ids]
    options = question_data["options"] || question_data[:options]

    if option_word_ids && options && length(option_word_ids) == length(options) do
      # Find the index of the student's answer in options (answer is the English text value)
      selected_index = Enum.find_index(options, &normalize_equals(&1, answer))

      # Find the index of the correct answer in options (correct_answer is also English text)
      correct_index = Enum.find_index(options, &normalize_equals(&1, correct_answer))

      if selected_index && correct_index do
        # Compare word_ids at the same indices
        selected_word_id = Enum.at(option_word_ids, selected_index)
        correct_word_id = Enum.at(option_word_ids, correct_index)

        selected_word_id == correct_word_id
      else
        # Fallback to text comparison if indices not found
        answer_matches_any?(answer, correct_answer, question_data)
      end
    else
      # Standard text comparison for non-localized questions
      answer_matches_any?(answer, correct_answer, question_data)
    end
  end

  defp answer_matches_any?(answer, correct_answer, question_data) do
    normalized = normalize_answer(answer)

    if normalized == normalize_answer(correct_answer) do
      true
    else
      alt_answers =
        question_data["alt_correct_answers"] || question_data[:alt_correct_answers] || []

      Enum.any?(alt_answers, &(normalize_answer(&1) == normalized))
    end
  end

  defp normalize_equals(a, b) do
    normalize_answer(a) == normalize_answer(b)
  end

  @doc """
  Normalizes an answer for comparison.
  """
  def normalize_answer(answer) when is_binary(answer) do
    answer
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\p{P}/u, "")
  end

  def normalize_answer(nil), do: ""

  def normalize_answer(answer), do: to_string(answer)

  @doc """
  Applies penalties to points based on attempts and hints used.
  - Each extra attempt: -25% of points
  - Each hint: -10% of points (non-listening steps)
  - Listening hint: -50% of points (single hint halves the earned points)
  - Minimum: 10% of original points (if correct)
  """
  def apply_penalties(max_points, attempts, hints_used, step_question_type \\ nil) do
    attempt_penalty = (attempts - 1) * 0.25
    hint_penalty = calculate_hint_penalty(hints_used, step_question_type)
    total_penalty = min(attempt_penalty + hint_penalty, 0.90)

    rounded_points = round(max_points * (1 - total_penalty))
    max(rounded_points, 1)
  end

  defp calculate_hint_penalty(hints_used, :listening) when hints_used > 0, do: 0.5
  defp calculate_hint_penalty(hints_used, _), do: hints_used * 0.10
end
