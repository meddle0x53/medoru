defmodule Medoru.Classrooms.ClassroomLessonProgress do
  @moduledoc """
  Schema for tracking lesson progress within a classroom.

  Tracks:
  - Lesson completion status
  - Points earned from lesson tests
  - Overall classroom progress
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom
  alias Medoru.Accounts.User
  alias Medoru.Content.Lesson
  alias Medoru.Tests.TestSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_lesson_progress" do
    # not_started, in_progress, completed
    field :status, :string, default: "not_started"
    field :progress_percent, :integer, default: 0
    field :points_earned, :integer, default: 0

    # Lesson test results
    field :test_score, :integer
    field :test_max_score, :integer

    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :classroom, Classroom
    belongs_to :user, User
    belongs_to :lesson, Lesson
    belongs_to :test_session, TestSession

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating or updating lesson progress.
  """
  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [
      :classroom_id,
      :user_id,
      :lesson_id,
      :status,
      :progress_percent,
      :points_earned,
      :test_session_id,
      :test_score,
      :test_max_score,
      :started_at,
      :completed_at
    ])
    |> validate_required([:classroom_id, :user_id, :lesson_id])
    |> validate_inclusion(:status, ["not_started", "in_progress", "completed"])
    |> validate_number(:progress_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:points_earned, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lesson_id)
    |> unique_constraint([:classroom_id, :user_id, :lesson_id],
      name: :classroom_lesson_progress_classroom_id_user_id_lesson_id_index
    )
  end

  @doc """
  Changeset for starting a lesson.
  """
  def start_changeset(progress, attrs) do
    progress
    |> cast(attrs, [:status, :started_at, :progress_percent])
    |> put_change(:status, "in_progress")
    |> put_change(:started_at, DateTime.utc_now())
  end

  @doc """
  Changeset for completing a lesson.
  """
  def complete_changeset(progress, attrs) do
    progress
    |> cast(attrs, [
      :status,
      :progress_percent,
      :points_earned,
      :test_session_id,
      :test_score,
      :test_max_score,
      :completed_at
    ])
    |> put_change(:status, "completed")
    |> put_change(:progress_percent, 100)
    |> put_change(:completed_at, DateTime.utc_now())
    |> validate_required([:points_earned])
  end
end
