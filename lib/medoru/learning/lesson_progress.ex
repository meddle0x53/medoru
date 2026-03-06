defmodule Medoru.Learning.LessonProgress do
  @moduledoc """
  Schema for tracking user progress through lessons.
  Status: :started, :completed
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:started, :completed]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lesson_progress" do
    field :status, Ecto.Enum, values: @statuses, default: :started
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :progress_percentage, :integer, default: 0

    belongs_to :user, Medoru.Accounts.User
    belongs_to :lesson, Medoru.Content.Lesson

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lesson_progress, attrs) do
    lesson_progress
    |> cast(attrs, [
      :status,
      :started_at,
      :completed_at,
      :progress_percentage,
      :user_id,
      :lesson_id
    ])
    |> validate_required([:user_id, :lesson_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:progress_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lesson_id)
    |> unique_constraint([:user_id, :lesson_id], name: :lesson_progress_user_id_lesson_id_index)
  end

  @doc """
  Marks the lesson as completed, setting completed_at and status.
  """
  def complete_changeset(lesson_progress) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    lesson_progress
    |> change(%{
      status: :completed,
      completed_at: now,
      progress_percentage: 100
    })
  end

  @doc """
  Updates the progress percentage.
  """
  def update_progress_changeset(lesson_progress, percentage) do
    lesson_progress
    |> change(%{progress_percentage: percentage})
  end
end
