defmodule Medoru.Content.CustomLessonWord do
  @moduledoc """
  Schema for words within a custom lesson.

  Allows teachers to:
  - Override the default word meaning for lesson context
  - Add custom example sentences
  - Control word ordering within the lesson
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Content.{CustomLesson, Word}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_lesson_words" do
    field :position, :integer
    field :custom_meaning, :string
    field :examples, {:array, :string}, default: []

    belongs_to :custom_lesson, CustomLesson
    belongs_to :word, Word

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for adding a word to a lesson.
  """
  def changeset(lesson_word, attrs) do
    lesson_word
    |> cast(attrs, [:position, :custom_meaning, :examples, :custom_lesson_id, :word_id])
    |> validate_required([:position, :custom_lesson_id, :word_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_length(:custom_meaning, max: 500)
    |> validate_examples()
    |> foreign_key_constraint(:custom_lesson_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:custom_lesson_id, :word_id],
      name: :custom_lesson_words_custom_lesson_id_word_id_index
    )
  end

  @doc """
  Changeset for updating lesson word details.
  """
  def update_changeset(lesson_word, attrs) do
    lesson_word
    |> cast(attrs, [:custom_meaning, :examples])
    |> validate_length(:custom_meaning, max: 500)
    |> validate_examples()
  end

  @doc """
  Changeset for reordering words.
  """
  def reorder_changeset(lesson_word, position) do
    lesson_word
    |> cast(%{position: position}, [:position])
    |> validate_required([:position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end

  defp validate_examples(changeset) do
    changeset
    |> validate_change(:examples, fn :examples, examples ->
      cond do
        length(examples) > 5 ->
          [examples: "can have at most 5 examples"]

        Enum.any?(examples, fn ex -> String.length(ex) > 200 end) ->
          [examples: "each example can be at most 200 characters"]

        true ->
          []
      end
    end)
  end
end
