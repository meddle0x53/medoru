defmodule Medoru.Classrooms.ClassroomLessonProgress do
  @moduledoc """
  Schema for tracking lesson progress within a classroom.

  Tracks:
  - Lesson completion status for both system and custom lessons
  - Points earned from lesson tests (system) or completion (custom)
  - Overall classroom progress
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom
  alias Medoru.Accounts.User
  alias Medoru.Content.{Lesson, CustomLesson}
  alias Medoru.Tests.TestSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_lesson_progress" do
    # not_started, in_progress, completed
    field :status, :string, default: "not_started"
    field :progress_percent, :integer, default: 0
    field :points_earned, :integer, default: 0
    field :lesson_source, :string, default: "system"

    # Lesson test results (for system lessons)
    field :test_score, :integer
    field :test_max_score, :integer

    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :classroom, Classroom
    belongs_to :user, User
    belongs_to :lesson, Lesson
    belongs_to :custom_lesson, CustomLesson
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
      :custom_lesson_id,
      :status,
      :progress_percent,
      :points_earned,
      :lesson_source,
      :test_session_id,
      :test_score,
      :test_max_score,
      :started_at,
      :completed_at
    ])
    |> validate_required([:classroom_id, :user_id, :lesson_source])
    |> validate_lesson_presence()
    |> validate_inclusion(:status, ["not_started", "in_progress", "completed"])
    |> validate_inclusion(:lesson_source, ["system", "custom"])
    |> validate_number(:progress_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:points_earned, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:custom_lesson_id)
    |> unique_constraint([:classroom_id, :user_id, :lesson_id],
      name: :classroom_lesson_progress_classroom_id_user_id_lesson_id_index
    )
  end

  defp validate_lesson_presence(changeset) do
    lesson_id = get_field(changeset, :lesson_id)
    custom_lesson_id = get_field(changeset, :custom_lesson_id)
    lesson_source = get_field(changeset, :lesson_source)

    cond do
      lesson_source == "system" && is_nil(lesson_id) ->
        add_error(changeset, :lesson_id, "is required for system lessons")

      lesson_source == "custom" && is_nil(custom_lesson_id) ->
        add_error(changeset, :custom_lesson_id, "is required for custom lessons")

      true ->
        changeset
    end
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
    |> maybe_require_test_session()
  end

  defp maybe_require_test_session(changeset) do
    lesson_source = get_field(changeset, :lesson_source)
    test_session_id = get_field(changeset, :test_session_id)

    # System lessons require test_session_id, custom lessons don't
    if lesson_source == "system" && is_nil(test_session_id) do
      add_error(changeset, :test_session_id, "is required for system lesson completion")
    else
      changeset
    end
  end
end
