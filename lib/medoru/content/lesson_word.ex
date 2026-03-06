defmodule Medoru.Content.LessonWord do
  @moduledoc """
  Join schema linking lessons to words (vocabulary).
  Each LessonWord record represents one word in a lesson,
  with position tracking for ordering.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lesson_words" do
    field :position, :integer

    belongs_to :lesson, Medoru.Content.Lesson
    belongs_to :word, Medoru.Content.Word

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lesson_word, attrs) do
    lesson_word
    |> cast(attrs, [:position, :lesson_id, :word_id])
    |> validate_required([:position, :lesson_id, :word_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:lesson_id, :position],
      name: :lesson_words_lesson_id_position_index
    )
    |> unique_constraint([:lesson_id, :word_id],
      name: :lesson_words_lesson_id_word_id_index
    )
  end
end
