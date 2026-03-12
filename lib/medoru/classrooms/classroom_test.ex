defmodule Medoru.Classrooms.ClassroomTest do
  @moduledoc """
  Schema for linking tests to classrooms (publishing).

  A teacher can publish the same test to multiple classrooms.
  Each classroom can have multiple tests published to it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom
  alias Medoru.Accounts.User
  alias Medoru.Tests.Test

  @statuses [:active, :archived, :unpublished]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_tests" do
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :published_at, :utc_datetime_usec
    field :unpublished_at, :utc_datetime_usec
    field :due_date, :utc_datetime
    field :max_attempts, :integer
    field :settings, :map, default: %{}

    # Publishing history
    field :publish_count, :integer, default: 1

    belongs_to :classroom, Classroom
    belongs_to :test, Test
    belongs_to :published_by, User, foreign_key: :published_by_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(classroom_test, attrs) do
    classroom_test
    |> cast(attrs, [
      :status,
      :published_at,
      :unpublished_at,
      :due_date,
      :max_attempts,
      :settings,
      :publish_count,
      :classroom_id,
      :test_id,
      :published_by_id
    ])
    |> validate_required([
      :status,
      :classroom_id,
      :test_id,
      :published_by_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:max_attempts, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:test_id)
    |> foreign_key_constraint(:published_by_id)
    |> unique_constraint([:classroom_id, :test_id],
      name: :classroom_tests_classroom_id_test_id_index,
      message: "This test is already published to this classroom"
    )
  end

  @doc """
  Changeset for publishing a test to a classroom.
  """
  def publish_changeset(classroom_test, attrs) do
    attrs =
      attrs
      |> Map.put(:status, :active)
      |> Map.put(:published_at, DateTime.utc_now())

    changeset(classroom_test, attrs)
  end

  @doc """
  Changeset for unpublishing a test from a classroom.
  """
  def unpublish_changeset(classroom_test) do
    changeset(classroom_test, %{
      status: :unpublished,
      unpublished_at: DateTime.utc_now()
    })
  end

  @doc """
  Changeset for republishing an unpublished test.
  """
  def republish_changeset(classroom_test) do
    changeset(classroom_test, %{
      status: :active,
      published_at: DateTime.utc_now(),
      unpublished_at: nil,
      publish_count: classroom_test.publish_count + 1
    })
  end

  @doc """
  Changeset for archiving a published test.
  """
  def archive_changeset(classroom_test) do
    changeset(classroom_test, %{status: :archived})
  end
end
