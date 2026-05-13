defmodule Medoru.Games.KanaFallingSession do
  @moduledoc """
  Schema for kana falling game sessions.

  Sessions are only created when a game finishes (not during gameplay).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Games.Game

  @statuses ["completed"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kana_falling_sessions" do
    field :status, :string, default: "completed"
    field :score, :integer, default: 0
    field :highest_speed_reached, :integer, default: 1
    field :lives_remaining, :integer, default: 0
    field :lives_used, :integer, default: 0
    field :highest_row_reached, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :game, Game
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kana_falling_session, attrs) do
    kana_falling_session
    |> cast(attrs, [
      :status,
      :score,
      :highest_speed_reached,
      :lives_remaining,
      :lives_used,
      :highest_row_reached,
      :started_at,
      :completed_at,
      :game_id,
      :user_id
    ])
    |> validate_required([
      :status,
      :score,
      :highest_speed_reached,
      :lives_remaining,
      :lives_used,
      :game_id,
      :user_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:highest_speed_reached, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:user_id)
  end
end
