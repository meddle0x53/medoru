defmodule Medoru.Learning.WordSetWord do
  @moduledoc """
  Schema for words within a word set.
  
  Tracks the position of each word for custom ordering.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Learning.WordSet
  alias Medoru.Content.Word

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_set_words" do
    field :position, :integer

    belongs_to :word_set, WordSet
    belongs_to :word, Word

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_set_word, attrs) do
    word_set_word
    |> cast(attrs, [:position, :word_set_id, :word_id])
    |> validate_required([:position, :word_set_id, :word_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:word_set_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:word_set_id, :word_id],
      name: :word_set_words_word_set_id_word_id_index
    )
  end

  @doc """
  Changeset for reordering a word within a set.
  """
  def reorder_changeset(word_set_word, position) do
    word_set_word
    |> cast(%{position: position}, [:position])
    |> validate_required([:position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
