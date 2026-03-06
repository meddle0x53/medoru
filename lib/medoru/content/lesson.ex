defmodule Medoru.Content.Lesson do
  @moduledoc """
  Schema for Lessons - structured vocabulary learning units.
  Lessons contain words that teach kanji through context.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @lesson_types [:reading, :writing, :listening, :speaking, :grammar]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lessons" do
    field :title, :string
    field :description, :string
    field :difficulty, :integer
    field :order_index, :integer
    field :lesson_type, Ecto.Enum, values: @lesson_types, default: :reading

    has_many :lesson_words, Medoru.Content.LessonWord, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [:title, :description, :difficulty, :order_index, :lesson_type])
    |> validate_required([:title, :description, :difficulty, :order_index, :lesson_type])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:order_index, greater_than_or_equal_to: 0)
    |> validate_inclusion(:lesson_type, @lesson_types)
    |> unique_constraint([:difficulty, :order_index])
  end
end
