defmodule Medoru.Learning.WordSet do
  @moduledoc """
  Schema for Word Sets - user-created collections of words for focused study.
  
  A word set can contain up to 100 words and has an optional associated practice test.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Tests.Test
  alias Medoru.Learning.WordSetWord

  @max_words 100

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_sets" do
    field :name, :string
    field :description, :string
    field :word_count, :integer, default: 0

    belongs_to :user, User
    belongs_to :practice_test, Test
    has_many :word_set_words, WordSetWord, preload_order: [asc: :position]
    has_many :words, through: [:word_set_words, :word]

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_set, attrs) do
    word_set
    |> cast(attrs, [:name, :description, :word_count, :user_id, :practice_test_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:word_count, greater_than_or_equal_to: 0, less_than_or_equal_to: @max_words)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:practice_test_id)
  end

  @doc """
  Changeset for updating word count.
  """
  def update_word_count_changeset(word_set, count) do
    word_set
    |> cast(%{word_count: count}, [:word_count])
    |> validate_number(:word_count, greater_than_or_equal_to: 0, less_than_or_equal_to: @max_words)
  end

  @doc """
  Changeset for associating a practice test.
  """
  def associate_test_changeset(word_set, test_id) do
    word_set
    |> cast(%{practice_test_id: test_id}, [:practice_test_id])
    |> foreign_key_constraint(:practice_test_id)
  end

  @doc """
  Returns the maximum number of words allowed in a word set.
  """
  def max_words, do: @max_words
end
