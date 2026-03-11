defmodule Medoru.Classrooms.ClassroomMembership do
  @moduledoc """
  Schema for classroom memberships.

  Links users to classrooms with a status (pending, approved, rejected, left, removed)
  and tracks membership data like points earned.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classroom_memberships" do
    field :status, Ecto.Enum,
      values: [:pending, :approved, :rejected, :left, :removed],
      default: :pending

    field :role, Ecto.Enum, values: [:student, :assistant], default: :student
    field :joined_at, :utc_datetime
    field :points, :integer, default: 0
    field :settings, :map, default: %{}

    belongs_to :classroom, Medoru.Classrooms.Classroom
    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:status, :role, :joined_at, :points, :settings, :classroom_id, :user_id])
    |> validate_required([:status, :role, :points, :classroom_id, :user_id])
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> unique_constraint([:classroom_id, :user_id])
    |> foreign_key_constraint(:classroom_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for approving a membership application.
  """
  def approve_changeset(membership) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    membership
    |> change(status: :approved, joined_at: now)
  end

  @doc """
  Changeset for rejecting a membership application.
  """
  def reject_changeset(membership) do
    membership
    |> change(status: :rejected)
  end

  @doc """
  Changeset for removing a member from the classroom.
  """
  def remove_changeset(membership) do
    membership
    |> change(status: :removed)
  end

  @doc """
  Changeset for a member leaving the classroom.
  """
  def leave_changeset(membership) do
    membership
    |> change(status: :left)
  end
end
