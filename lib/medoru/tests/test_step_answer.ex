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
      :answer,
      :is_correct,
      :test_session_id,
      :test_step_id
    ])
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
  def answer_changeset(test_step_answer, attrs, correct_answer, max_points) do
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

    is_correct = normalize_answer(answer) == normalize_answer(correct_answer)

    # Calculate points with penalties
    points_earned =
      if is_correct do
        apply_penalties(max_points, attempts, hints_used)
      else
        0
      end

    changeset
    |> put_change(:is_correct, is_correct)
    |> put_change(:points_earned, points_earned)
  end

  @doc """
  Normalizes an answer for comparison.
  """
  def normalize_answer(answer) when is_binary(answer) do
    answer
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end

  def normalize_answer(nil), do: ""

  def normalize_answer(answer), do: to_string(answer)

  @doc """
  Applies penalties to points based on attempts and hints used.
  - Each extra attempt: -25% of points
  - Each hint: -10% of points
  - Minimum: 10% of original points (if correct)
  """
  def apply_penalties(max_points, attempts, hints_used) do
    attempt_penalty = (attempts - 1) * 0.25
    hint_penalty = hints_used * 0.10
    total_penalty = min(attempt_penalty + hint_penalty, 0.90)

    rounded_points = round(max_points * (1 - total_penalty))
    max(rounded_points, 1)
  end
end
