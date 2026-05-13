defmodule Medoru.Games.KanaMemoryCardGame do
  @moduledoc """
  Schema for kana memory card game configuration.

  Stores board size, attempts, require_reading flag, and selected kana characters.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @board_sizes ["4x4", "5x4", "6x4", "6x5", "6x6"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kana_memory_card_games" do
    field :board_size, :string
    field :max_attempts, :integer
    field :require_reading, :boolean, default: false
    field :selected_kana, {:array, :string}, default: []

    belongs_to :game, Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kana_memory_card_game, attrs) do
    kana_memory_card_game
    |> cast(attrs, [
      :board_size,
      :max_attempts,
      :require_reading,
      :selected_kana,
      :game_id
    ])
    |> validate_required([:board_size, :max_attempts, :game_id])
    |> validate_inclusion(:board_size, @board_sizes)
    |> validate_number(:max_attempts, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:game_id)
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
    end
  end

  @doc """
  Returns the number of unique kana needed for a given board size.
  """
  def kana_needed(board_size) do
    div(board_size_to_card_count(board_size), 2)
  end
end
