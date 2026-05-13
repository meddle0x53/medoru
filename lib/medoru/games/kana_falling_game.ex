defmodule Medoru.Games.KanaFallingGame do
  @moduledoc """
  Schema for kana falling (typing) game configuration.

  Teachers configure:
  - Initial falling speed (1-10)
  - Speed increase threshold (points needed to speed up)
  - Starting lives
  - Extra life threshold (points needed to earn a life)
  - Points per correct kana
  - Which kana characters participate
  - Optional background image
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @speeds 1..10

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kana_falling_games" do
    field :initial_speed, :integer, default: 1
    field :speed_increase_threshold, :integer, default: 50
    field :lives, :integer, default: 3
    field :extra_life_threshold, :integer, default: 100
    field :points_per_kana, :integer, default: 1
    field :selected_kana, {:array, :string}, default: []
    field :background_image, :string

    belongs_to :game, Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kana_falling_game, attrs) do
    kana_falling_game
    |> cast(attrs, [
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :points_per_kana,
      :selected_kana,
      :background_image,
      :game_id
    ])
    |> validate_required([
      :initial_speed,
      :speed_increase_threshold,
      :lives,
      :extra_life_threshold,
      :points_per_kana,
      :selected_kana,
      :game_id
    ])
    |> validate_inclusion(:initial_speed, @speeds)
    |> validate_number(:speed_increase_threshold, greater_than: 0)
    |> validate_number(:lives, greater_than: 0)
    |> validate_number(:extra_life_threshold, greater_than: 0)
    |> validate_number(:points_per_kana, greater_than: 0)
    |> validate_length(:selected_kana, min: 1)
    |> foreign_key_constraint(:game_id)
  end

  @doc """
  Maps speed level to milliseconds per row.
  """
  def speed_to_ms(speed) do
    case speed do
      1 -> 2000
      2 -> 1800
      3 -> 1600
      4 -> 1400
      5 -> 1000
      6 -> 900
      7 -> 800
      8 -> 600
      9 -> 500
      10 -> 300
      _ -> 2000
    end
  end
end
