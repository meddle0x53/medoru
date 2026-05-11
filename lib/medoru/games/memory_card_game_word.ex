defmodule Medoru.Games.MemoryCardGameWord do
  @moduledoc """
  Join schema linking memory card games to words.

  Each word can have a custom point value for the game.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.MemoryCardGame
  alias Medoru.Content.Word

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memory_card_game_words" do
    field :points, :integer, default: 1
    field :position, :integer

    belongs_to :memory_card_game, MemoryCardGame
    belongs_to :word, Word

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(memory_card_game_word, attrs) do
    memory_card_game_word
    |> cast(attrs, [:points, :position, :memory_card_game_id, :word_id])
    |> validate_required([:points, :memory_card_game_id, :word_id])
    |> validate_number(:points, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:memory_card_game_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:memory_card_game_id, :word_id])
  end
end
