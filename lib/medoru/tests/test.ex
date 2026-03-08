defmodule Medoru.Tests.Test do
  @moduledoc """
  Schema for Tests - multi-step assessment units.

  Tests can be of various types:
  - :daily - Auto-generated daily review test
  - :lesson - Test at the end of a lesson
  - :teacher - Custom test created by teachers
  - :practice - Self-practice test

  Tests have multiple steps, each worth different points based on difficulty.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @test_types [:daily, :lesson, :teacher, :practice]
  @test_statuses [:draft, :ready, :published, :archived]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tests" do
    field :title, :string
    field :description, :string
    field :test_type, Ecto.Enum, values: @test_types
    field :status, Ecto.Enum, values: @test_statuses, default: :draft
    field :total_points, :integer, default: 0
    field :time_limit_seconds, :integer
    field :is_system, :boolean, default: false
    field :metadata, :map, default: %{}

    # For lesson tests
    belongs_to :lesson, Medoru.Content.Lesson

    # For teacher tests
    belongs_to :creator, Medoru.Accounts.User

    has_many :test_steps, Medoru.Tests.TestStep, preload_order: [asc: :order_index]
    has_many :test_sessions, Medoru.Tests.TestSession

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test, attrs) do
    test
    |> cast(attrs, [
      :title,
      :description,
      :test_type,
      :status,
      :total_points,
      :time_limit_seconds,
      :is_system,
      :metadata,
      :lesson_id,
      :creator_id
    ])
    |> validate_required([:title, :test_type, :status])
    |> validate_inclusion(:test_type, @test_types)
    |> validate_inclusion(:status, @test_statuses)
    |> validate_number(:total_points, greater_than_or_equal_to: 0)
    |> validate_number(:time_limit_seconds,
      greater_than_or_equal_to: 60,
      less_than_or_equal_to: 3600
    )
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Changeset for publishing a test.
  """
  def publish_changeset(test) do
    change(test, status: :published)
  end

  @doc """
  Changeset for marking a test as ready.
  """
  def ready_changeset(test) do
    change(test, status: :ready)
  end

  @doc """
  Changeset for archiving a test.
  """
  def archive_changeset(test) do
    change(test, status: :archived)
  end
end
