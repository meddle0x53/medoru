defmodule Medoru.Tests.TestSession do
  @moduledoc """
  Schema for Test Sessions - tracks a user's attempt at a test.

  Status flow:
  :started -> :in_progress -> :completed/:abandoned/:timed_out

  Tracks:
  - Overall score and percentage
  - Time taken
  - Current step position
  - Individual step answers
  """
  use Ecto.Schema
  import Ecto.Changeset

  @session_statuses [:started, :in_progress, :completed, :abandoned, :timed_out]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "test_sessions" do
    field :status, Ecto.Enum, values: @session_statuses, default: :started
    field :score, :integer, default: 0
    field :total_possible, :integer, default: 0
    field :percentage, :float
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :time_spent_seconds, :integer, default: 0
    field :current_step_index, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :user, Medoru.Accounts.User
    belongs_to :test, Medoru.Tests.Test

    has_many :test_step_answers, Medoru.Tests.TestStepAnswer, preload_order: [asc: :step_index]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test_session, attrs) do
    test_session
    |> cast(attrs, [
      :status,
      :score,
      :total_possible,
      :percentage,
      :started_at,
      :completed_at,
      :time_spent_seconds,
      :current_step_index,
      :metadata,
      :user_id,
      :test_id
    ])
    |> validate_required([:status, :user_id, :test_id])
    |> validate_inclusion(:status, @session_statuses)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:total_possible, greater_than_or_equal_to: 0)
    |> validate_number(:percentage,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:current_step_index, greater_than_or_equal_to: 0)
    |> validate_number(:time_spent_seconds, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:test_id)
    |> calculate_percentage()
  end

  @doc """
  Changeset for starting a test session.
  """
  def start_changeset(test_session, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    test_session
    |> cast(attrs, [:user_id, :test_id])
    |> validate_required([:user_id, :test_id])
    |> put_change(:status, :started)
    |> put_change(:started_at, now)
    |> put_change(:current_step_index, 0)
    |> put_change(:score, 0)
    |> put_change(:time_spent_seconds, 0)
  end

  @doc """
  Changeset for marking a session as in progress.
  """
  def progress_changeset(test_session, current_step_index, time_spent) do
    test_session
    |> change(
      status: :in_progress,
      current_step_index: current_step_index,
      time_spent_seconds: time_spent
    )
  end

  @doc """
  Changeset for completing a test session.
  """
  def complete_changeset(test_session, score, total_possible, time_spent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    percentage = if total_possible > 0, do: score / total_possible * 100, else: 0.0

    test_session
    |> change(
      status: :completed,
      score: score,
      total_possible: total_possible,
      percentage: Float.round(percentage, 2),
      completed_at: now,
      time_spent_seconds: time_spent,
      current_step_index: test_session.current_step_index
    )
  end

  @doc """
  Changeset for abandoning a test session.
  """
  def abandon_changeset(test_session, time_spent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    test_session
    |> change(
      status: :abandoned,
      completed_at: now,
      time_spent_seconds: time_spent
    )
  end

  @doc """
  Changeset for timing out a test session.
  """
  def timeout_changeset(test_session, score, total_possible, time_spent) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    percentage = if total_possible > 0, do: score / total_possible * 100, else: 0.0

    test_session
    |> change(
      status: :timed_out,
      score: score,
      total_possible: total_possible,
      percentage: Float.round(percentage, 2),
      completed_at: now,
      time_spent_seconds: time_spent
    )
  end

  defp calculate_percentage(changeset) do
    score = get_field(changeset, :score)
    total = get_field(changeset, :total_possible)

    if score && total && total > 0 do
      percentage = Float.round(score / total * 100, 2)
      put_change(changeset, :percentage, percentage)
    else
      changeset
    end
  end
end
