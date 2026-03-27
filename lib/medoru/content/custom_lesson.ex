defmodule Medoru.Content.CustomLesson do
  @moduledoc """
  Schema for custom lessons created by teachers.

  Unlike system lessons (auto-generated from Core 6000), custom lessons allow
  teachers to:
  - Select specific words from the vocabulary database
  - Customize meanings per lesson context
  - Add example sentences
  - Publish to specific classrooms

  Students complete custom lessons by studying the material (no test required).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Content.CustomLessonWord
  alias Medoru.Classrooms.ClassroomCustomLesson
  alias Medoru.Tests.Test

  @lesson_subtypes ["vocabulary", "grammar"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_lessons" do
    field :title, :string
    field :description, :string
    field :lesson_type, :string, default: "reading"
    field :lesson_subtype, :string, default: "vocabulary"
    field :difficulty, :integer
    field :status, :string, default: "draft"
    field :word_count, :integer, default: 0

    # Test configuration
    field :requires_test, :boolean, default: false
    field :include_writing, :boolean, default: false

    belongs_to :creator, User
    belongs_to :test, Test
    has_many :custom_lesson_words, CustomLessonWord, preload_order: [asc: :position]
    has_many :words, through: [:custom_lesson_words, :word]
    has_many :classroom_custom_lessons, ClassroomCustomLesson
    has_many :classrooms, through: [:classroom_custom_lessons, :classroom]
    has_many :grammar_lesson_steps, Medoru.Content.GrammarLessonStep,
      preload_order: [asc: :position]

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating or updating a custom lesson.
  """
  def changeset(custom_lesson, attrs) do
    custom_lesson
    |> cast(attrs, [
      :title,
      :description,
      :lesson_type,
      :lesson_subtype,
      :difficulty,
      :status,
      :word_count,
      :creator_id,
      :requires_test,
      :include_writing
    ])
    |> validate_required([:title, :lesson_type, :lesson_subtype, :status, :creator_id])
    |> validate_length(:title, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:lesson_type, ["reading"])
    |> validate_inclusion(:lesson_subtype, @lesson_subtypes)
    |> validate_inclusion(:status, ["draft", "published", "archived"])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:word_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Changeset for publishing a lesson.
  """
  def publish_changeset(custom_lesson) do
    custom_lesson
    |> cast(%{status: "published"}, [:status])
    |> validate_inclusion(:status, ["published"])
  end

  @doc """
  Changeset for archiving a lesson.
  """
  def archive_changeset(custom_lesson) do
    custom_lesson
    |> cast(%{status: "archived"}, [:status])
    |> validate_inclusion(:status, ["archived"])
  end

  @doc """
  Changeset for unarchiving a lesson (restores to published status).
  """
  def unarchive_changeset(custom_lesson) do
    custom_lesson
    |> cast(%{status: "published"}, [:status])
    |> validate_inclusion(:status, ["published"])
  end

  @doc """
  Changeset for updating word count.
  """
  def update_word_count_changeset(custom_lesson, count) do
    custom_lesson
    |> cast(%{word_count: count}, [:word_count])
    |> validate_number(:word_count, greater_than_or_equal_to: 0, less_than_or_equal_to: 50)
  end
end
