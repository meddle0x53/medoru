defmodule Medoru.Games.RadicalHuntGame do
  @moduledoc """
  Schema for radical hunt game configuration.

  Teachers configure:
  - Which radical to hunt for
  - Timeout in seconds (default 120)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "radical_hunt_games" do
    field :radical, :string
    field :timeout_seconds, :integer, default: 120

    belongs_to :game, Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(radical_hunt_game, attrs) do
    radical_hunt_game
    |> cast(attrs, [:radical, :timeout_seconds, :game_id])
    |> validate_required([:radical, :timeout_seconds, :game_id])
    |> validate_length(:radical, is: 1)
    |> validate_number(:timeout_seconds, greater_than: 0, less_than_or_equal_to: 600)
    |> foreign_key_constraint(:game_id)
  end
end
