defmodule Medoru.Games.WordsFallingGame do
  @moduledoc """
  Schema for words falling (typing) game configuration.

  Teachers configure:
  - Initial falling speed (1-10)
  - Speed increase threshold
  - Starting lives
  - Extra life threshold
  - Which words participate and their individual points
  - Game mode (meaning or reading)
  - On-screen keyboard type (hiragana or latin) for reading mode
  - Optional background image
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @speeds 1..10
  @game_modes [0, 1]
  @keyboard_types ["hiragana", "latin"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "words_falling_games" do
    field :initial_speed, :integer, default: 1
    field :speed_increase_threshold, :integer, default: 50
    field :lives, :integer, default: 3
    field :extra_life_threshold, :integer, default: 100
    field :selected_words, {:array, :binary_id}
    field :word_points, :map, default: %{}
    field :game_mode, :integer, default: 0
    field :keyboard_type, :string, default: "latin"
    field :word_colors, :map, default: %{}
    field :background_image, :string

    belongs_to :game, Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(words_falling_game, attrs) do
    words_falling_game
    |> cast(attrs, [
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :selected_words,
      :word_points,
      :game_mode,
      :keyboard_type,
      :word_colors,
      :background_image,
      :game_id
    ])
    |> validate_required([
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :selected_words,
      :word_points,
      :game_mode,
      :keyboard_type,
      :game_id
    ])
    |> validate_inclusion(:initial_speed, @speeds)
    |> validate_inclusion(:game_mode, @game_modes)
    |> validate_inclusion(:keyboard_type, @keyboard_types)
    |> validate_number(:speed_increase_threshold, greater_than: 0)
    |> validate_number(:lives, greater_than: 0)
    |> validate_number(:extra_life_threshold, greater_than: 0)
    |> validate_length(:selected_words, min: 1, message: "at least 1 word required")
    |> foreign_key_constraint(:game_id)
  end

  @doc """
  Maps speed level to milliseconds per row.
  """
  def speed_to_ms(speed) do
    case speed do
      1 -> 1800
      2 -> 1600
      3 -> 1300
      4 -> 1000
      5 -> 800
      6 -> 700
      7 -> 500
      8 -> 400
      9 -> 300
      10 -> 100
      _ -> 1800
    end
  end

  @doc """
  Returns the game mode atom for a given integer.
  """
  def game_mode_label(mode) do
    case mode do
      0 -> :meaning
      1 -> :reading
      _ -> :meaning
    end
  end
end
