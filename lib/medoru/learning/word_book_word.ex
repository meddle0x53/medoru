defmodule Medoru.Learning.WordBookWord do
  @moduledoc """
  Schema for words within a word book.

  Tracks the position of each word for custom ordering.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Learning.WordBook
  alias Medoru.Content.Word

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_book_words" do
    field :position, :integer

    belongs_to :word_book, WordBook
    belongs_to :word, Word

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_book_word, attrs) do
    word_book_word
    |> cast(attrs, [:position, :word_book_id, :word_id])
    |> validate_required([:position, :word_book_id, :word_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:word_book_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:word_book_id, :word_id],
      name: :word_book_words_word_book_id_word_id_index
    )
  end

  @doc """
  Changeset for reordering a word within a book.
  """
  def reorder_changeset(word_book_word, position) do
    word_book_word
    |> cast(%{position: position}, [:position])
    |> validate_required([:position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
