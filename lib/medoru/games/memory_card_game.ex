defmodule Medoru.Games.MemoryCardGame do
  @moduledoc """
  Schema for memory card game configuration.

  Stores board size, attempts, collection conditions, and associated words.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @board_sizes ["4x4", "5x4", "6x4", "6x5", "6x6", "8x8", "10x10"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memory_card_games" do
    field :board_size, :string
    field :max_attempts, :integer
    field :meaning_required_for_collection, :boolean, default: false
    field :pronunciation_required_for_collection, :boolean, default: false
    field :meaning_or_pronunciation_required_for_collection, :boolean, default: false

    belongs_to :game, Game
    has_many :memory_card_game_words, Medoru.Games.MemoryCardGameWord

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(memory_card_game, attrs) do
    memory_card_game
    |> cast(attrs, [
      :board_size,
      :max_attempts,
      :meaning_required_for_collection,
      :pronunciation_required_for_collection,
      :meaning_or_pronunciation_required_for_collection,
      :game_id
    ])
    |> validate_required([:board_size, :max_attempts, :game_id])
    |> validate_inclusion(:board_size, @board_sizes)
    |> validate_number(:max_attempts, greater_than_or_equal_to: 1)
    |> validate_collection_conditions()
    |> foreign_key_constraint(:game_id)
  end

  defp validate_collection_conditions(changeset) do
    # All combinations of the three boolean flags are valid:
    # - none checked                -> :direct
    # - only meaning                -> :meaning
    # - only pronunciation          -> :pronunciation
    # - meaning + pronunciation     -> :meaning_and_pronunciation
    # - only meaning_or_pronunciation -> :meaning_or_pronunciation
    # - any combination with or set -> :meaning_or_pronunciation (checked first)
    changeset
  end

  @doc """
  Returns the number of cards for a given board size.
  """
  def board_size_to_card_count(board_size) do
    case board_size do
      "4x4" -> 16
      "5x4" -> 20
      "6x4" -> 24
      "6x5" -> 30
      "6x6" -> 36
      "8x8" -> 64
      "10x10" -> 100
    end
  end

  @doc """
  Returns the number of words needed for a given board size.
  """
  def words_needed(board_size) do
    div(board_size_to_card_count(board_size), 2)
  end

  @doc """
  Returns the collection type based on the boolean fields.
  """
  def collection_type(%__MODULE__{} = mcg) do
    cond do
      not mcg.meaning_required_for_collection and
          not mcg.pronunciation_required_for_collection and
          not mcg.meaning_or_pronunciation_required_for_collection ->
        :direct

      mcg.meaning_or_pronunciation_required_for_collection ->
        :meaning_or_pronunciation

      mcg.meaning_required_for_collection and mcg.pronunciation_required_for_collection ->
        :meaning_and_pronunciation

      mcg.meaning_required_for_collection ->
        :meaning

      mcg.pronunciation_required_for_collection ->
        :pronunciation

      true ->
        :direct
    end
  end
end
