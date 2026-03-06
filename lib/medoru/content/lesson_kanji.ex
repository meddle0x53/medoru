defmodule Medoru.Content.LessonKanji do
  @moduledoc """
  Join schema linking lessons to their constituent kanji.
  Each LessonKanji record represents one kanji character in a lesson,
  with position tracking for ordering.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lesson_kanjis" do
    field :position, :integer

    belongs_to :lesson, Medoru.Content.Lesson
    belongs_to :kanji, Medoru.Content.Kanji

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lesson_kanji, attrs) do
    lesson_kanji
    |> cast(attrs, [:position, :lesson_id, :kanji_id])
    |> validate_required([:position, :lesson_id, :kanji_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:kanji_id)
    |> unique_constraint([:lesson_id, :position],
      name: :lesson_kanjis_lesson_id_position_index
    )
    |> unique_constraint([:lesson_id, :kanji_id],
      name: :lesson_kanjis_lesson_id_kanji_id_index
    )
  end
end
