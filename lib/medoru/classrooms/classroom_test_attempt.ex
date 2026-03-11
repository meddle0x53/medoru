defmodule Medoru.Classrooms.ClassroomTestAttempt do
  @moduledoc """
  Schema for tracking test attempts within a classroom.

  Key features:
  - Timed tests with auto-submission
  - Points can go negative during test, final minimum is 0
  - Time remaining used as tie-breaker for rankings
  - One attempt per student unless reset by teacher
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom
  alias Medoru.Accounts.User
  alias Medoru.Tests.{Test, TestSession}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_test_attempts" do
    field :score, :integer, default: 0
    field :max_score, :integer
    field :points_earned, :integer, default: 0

    # Timing fields
    field :time_limit_seconds, :integer
    field :time_spent_seconds, :integer, default: 0
    field :time_remaining_seconds, :integer
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Status
    # in_progress, completed, timed_out
    field :status, :string, default: "in_progress"
    field :auto_submitted, :boolean, default: false

    # Reset tracking
    field :reset_count, :integer, default: 0
    field :reset_at, :utc_datetime_usec

    # Computed ranking score (points + time bonus factor)
    field :ranking_score, :decimal

    belongs_to :classroom, Classroom
    belongs_to :user, User
    belongs_to :test, Test
    belongs_to :test_session, TestSession
    belongs_to :reset_by, User, foreign_key: :reset_by_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a new test attempt.
  """
  def create_changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :classroom_id,
      :user_id,
      :test_id,
      :time_limit_seconds,
      :started_at
    ])
    |> validate_required([
      :classroom_id,
      :user_id,
      :test_id,
      :time_limit_seconds,
      :started_at
    ])
    |> set_initial_time_remaining()
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:test_id)
    |> unique_constraint([:classroom_id, :test_id, :user_id],
      name: :classroom_test_attempts_classroom_id_test_id_user_id_index,
      message: "You have already taken this test"
    )
  end

  @doc """
  Changeset for updating test progress during the attempt.
  """
  def progress_changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :score,
      :time_spent_seconds,
      :time_remaining_seconds
    ])
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:time_spent_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:time_remaining_seconds, greater_than_or_equal_to: 0)
  end

  @doc """
  Changeset for completing a test attempt.
  """
  def complete_changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :test_session_id,
      :score,
      :max_score,
      :points_earned,
      :time_spent_seconds,
      :time_remaining_seconds,
      :status,
      :auto_submitted,
      :completed_at
    ])
    |> validate_required([
      :score,
      :max_score,
      :points_earned,
      :time_spent_seconds,
      :time_remaining_seconds,
      :status,
      :completed_at
    ])
    |> ensure_non_negative_points()
    |> calculate_ranking_score()
  end

  @doc """
  Changeset for resetting a test attempt (teacher only).
  """
  def reset_changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :reset_count,
      :reset_at,
      :reset_by_id
    ])
    |> validate_required([:reset_count, :reset_at, :reset_by_id])
  end

  # Private functions

  defp set_initial_time_remaining(changeset) do
    case get_change(changeset, :time_limit_seconds) do
      nil -> changeset
      limit -> put_change(changeset, :time_remaining_seconds, limit)
    end
  end

  defp ensure_non_negative_points(changeset) do
    points = get_field(changeset, :points_earned) || 0

    if points < 0 do
      put_change(changeset, :points_earned, 0)
    else
      changeset
    end
  end

  # Ranking score: points + (time_remaining / time_limit) * 0.01
  # This ensures time only breaks ties, not overrides points
  defp calculate_ranking_score(changeset) do
    with points when is_integer(points) <- get_field(changeset, :points_earned),
         time_remaining when is_integer(time_remaining) <-
           get_field(changeset, :time_remaining_seconds),
         time_limit when is_integer(time_limit) <- get_field(changeset, :time_limit_seconds),
         true <- time_limit > 0 do
      time_bonus = Decimal.div(Decimal.new(time_remaining), Decimal.new(time_limit))
      time_bonus = Decimal.mult(time_bonus, Decimal.new("0.01"))
      score = Decimal.add(Decimal.new(points), time_bonus)

      put_change(changeset, :ranking_score, score)
    else
      _ -> changeset
    end
  end
end
