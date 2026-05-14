defmodule Medoru.Games.KanjiFallingGame do
  @moduledoc """
  Schema for kanji falling (typing) game configuration.

  Teachers configure:
  - Initial falling speed (1-10)
  - Speed increase threshold
  - Starting lives
  - Extra life threshold
  - Points per correct kanji
  - Which kanji characters participate
  - Reading type filter (any, onyomi, kunyomi)
  - On-screen keyboard type (hiragana grid or latin)
  - Optional background image
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @speeds 1..10
  @reading_types ["any", "onyomi", "kunyomi"]
  @keyboard_types ["hiragana", "latin"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kanji_falling_games" do
    field :initial_speed, :integer, default: 1
    field :speed_increase_threshold, :integer, default: 50
    field :lives, :integer, default: 3
    field :extra_life_threshold, :integer, default: 100
    field :points_per_kanji, :integer, default: 1
    field :selected_kanji, {:array, :string}
    field :reading_type, :string, default: "any"
    field :keyboard_type, :string, default: "hiragana"
    field :kanji_colors, :map, default: %{}
    field :background_image, :string

    belongs_to :game, Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kanji_falling_game, attrs) do
    kanji_falling_game
    |> cast(attrs, [
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :points_per_kanji,
      :selected_kanji,
      :reading_type,
      :keyboard_type,
      :kanji_colors,
      :background_image,
      :game_id
    ])
    |> validate_required([
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :points_per_kanji,
      :selected_kanji,
      :reading_type,
      :keyboard_type,
      :game_id
    ])
    |> validate_inclusion(:initial_speed, @speeds)
    |> validate_inclusion(:reading_type, @reading_types)
    |> validate_inclusion(:keyboard_type, @keyboard_types)
    |> validate_number(:speed_increase_threshold, greater_than: 0)
    |> validate_number(:lives, greater_than: 0)
    |> validate_length(:selected_kanji, min: 1, message: "at least 1 kanji required")
    |> validate_number(:extra_life_threshold, greater_than: 0)
    |> validate_number(:points_per_kanji, greater_than: 0)
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
end
