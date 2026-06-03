defmodule Medoru.Games.RadicalHuntSession do
  @moduledoc """
  Schema for radical hunt game sessions.

  Sessions are created when a game finishes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Games.Game

  @statuses ["completed"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "radical_hunt_sessions" do
    field :status, :string, default: "completed"
    field :score, :integer, default: 0
    field :kanji_found, {:array, :string}, default: []
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :game, Game
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(radical_hunt_session, attrs) do
    radical_hunt_session
    |> cast(attrs, [
      :status,
      :score,
      :kanji_found,
      :started_at,
      :completed_at,
      :game_id,
      :user_id
    ])
    |> validate_required([
      :status,
      :score,
      :game_id,
      :user_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:user_id)
  end
end
