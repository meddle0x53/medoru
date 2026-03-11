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
  @setup_states ["in_progress", "ready", "published", "archived"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tests" do
    field :title, :string
    field :description, :string
    field :test_type, Ecto.Enum, values: @test_types
    field :status, Ecto.Enum, values: @test_statuses, default: :draft
    field :setup_state, :string, default: "in_progress"
    field :total_points, :integer, default: 0
    field :time_limit_seconds, :integer
    field :max_attempts, :integer
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
      :setup_state,
      :total_points,
      :time_limit_seconds,
      :max_attempts,
      :is_system,
      :metadata,
      :lesson_id,
      :creator_id
    ])
    |> validate_required([:title, :test_type, :status, :setup_state])
    |> validate_inclusion(:test_type, @test_types)
    |> validate_inclusion(:status, @test_statuses)
    |> validate_inclusion(:setup_state, @setup_states)
    |> validate_number(:total_points, greater_than_or_equal_to: 0)
    |> validate_number(:time_limit_seconds,
      greater_than_or_equal_to: 60,
      less_than_or_equal_to: 7200
    )
    |> maybe_validate_max_attempts()
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:creator_id)
  end

  # Custom validation for max_attempts that allows nil
  defp maybe_validate_max_attempts(changeset) do
    case get_field(changeset, :max_attempts) do
      nil -> changeset
      value when is_integer(value) and value >= 1 and value <= 10 -> changeset
      _ -> add_error(changeset, :max_attempts, "must be between 1 and 10")
    end
  end

  @doc """
  Changeset for teacher test form (only validates user-editable fields).
  """
  def form_changeset(test, attrs) do
    test
    |> cast(attrs, [:title, :description, :time_limit_seconds, :max_attempts])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> maybe_validate_max_attempts()
  end

  @doc """
  Changeset for creating a teacher test.
  """
  def teacher_create_changeset(test, attrs) do
    # Normalize attrs to string keys and merge defaults
    attrs = for {k, v} <- attrs, into: %{}, do: {to_string(k), v}

    attrs =
      attrs
      |> Map.put_new("test_type", "teacher")
      |> Map.put_new("status", "draft")
      |> Map.put_new("setup_state", "in_progress")

    test
    |> changeset(attrs)
  end

  @doc """
  Changeset for publishing a test (legacy status field).
  """
  def publish_changeset(test) do
    change(test, status: :published)
  end

  @doc """
  Changeset for marking a test as ready (legacy status field).
  """
  def ready_changeset(test) do
    change(test, status: :ready)
  end

  @doc """
  Changeset for archiving a test (legacy status field).
  """
  def archive_changeset(test) do
    change(test, status: :archived)
  end

  @doc """
  Changeset for transitioning test setup_state.
  """
  def setup_state_changeset(test, new_state) when new_state in @setup_states do
    change(test, setup_state: new_state)
  end

  @doc """
  Changeset for marking test as ready.
  """
  def mark_ready_changeset(test) do
    setup_state_changeset(test, "ready")
  end

  @doc """
  Changeset for publishing a teacher test (setup_state).
  """
  def publish_teacher_changeset(test) do
    setup_state_changeset(test, "published")
  end

  @doc """
  Changeset for archiving a teacher test (setup_state).
  """
  def archive_teacher_changeset(test) do
    setup_state_changeset(test, "archived")
  end
end
