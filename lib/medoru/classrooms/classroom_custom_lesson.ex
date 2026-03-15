defmodule Medoru.Classrooms.ClassroomCustomLesson do
  @moduledoc """
  Schema for publishing custom lessons to classrooms.

  Similar to ClassroomTest, this manages the relationship between
  custom lessons and classrooms, including:
  - Publication status
  - Due dates
  - Points configuration
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Classrooms.Classroom
  alias Medoru.Content.CustomLesson

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_custom_lessons" do
    field :status, :string, default: "active"
    field :due_date, :date
    field :points_override, :integer
    field :published_at, :utc_datetime_usec
    field :unpublished_at, :utc_datetime_usec

    belongs_to :classroom, Classroom
    belongs_to :custom_lesson, CustomLesson
    belongs_to :published_by, User

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for publishing a lesson to a classroom.
  """
  def publish_changeset(classroom_lesson, attrs) do
    now = DateTime.utc_now()

    classroom_lesson
    |> cast(attrs, [
      :classroom_id,
      :custom_lesson_id,
      :published_by_id,
      :due_date,
      :points_override
    ])
    |> put_change(:status, "active")
    |> put_change(:published_at, now)
    |> put_change(:unpublished_at, nil)
    |> validate_required([:classroom_id, :custom_lesson_id, :published_by_id])
    |> validate_number(:points_override, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:custom_lesson_id)
    |> foreign_key_constraint(:published_by_id)
    |> unique_constraint([:classroom_id, :custom_lesson_id],
      name: :classroom_custom_lessons_unique_lesson
    )
  end

  @doc """
  Changeset for unpublishing a lesson from a classroom.
  """
  def unpublish_changeset(classroom_lesson) do
    now = DateTime.utc_now()

    classroom_lesson
    |> cast(%{status: "unpublished", unpublished_at: now}, [:status, :unpublished_at])
    |> validate_inclusion(:status, ["unpublished"])
  end

  @doc """
  Changeset for republishing a previously unpublished lesson.
  """
  def republish_changeset(classroom_lesson) do
    now = DateTime.utc_now()

    classroom_lesson
    |> cast(%{status: "active", published_at: now, unpublished_at: nil}, [
      :status,
      :published_at,
      :unpublished_at
    ])
    |> validate_inclusion(:status, ["active"])
  end
end
