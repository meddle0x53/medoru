defmodule Medoru.Games.MemoryCardSession do
  @moduledoc """
  Schema for a student's memory card game session.

  Stores the randomized card state, attempts used, and score.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Games.Game
  alias Medoru.Accounts.User

  @statuses [:in_progress, :completed, :abandoned]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memory_card_sessions" do
    field :status, Ecto.Enum, values: @statuses, default: :in_progress
    field :score, :integer, default: 0
    field :attempts_used, :integer, default: 0
    field :max_attempts, :integer
    field :cards_state, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :game, Game
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :score,
      :attempts_used,
      :max_attempts,
      :cards_state,
      :started_at,
      :completed_at,
      :game_id,
      :user_id
    ])
    |> validate_required([:status, :max_attempts, :game_id, :user_id])
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:attempts_used, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:game_id, :user_id],
      name: :memory_card_sessions_in_progress_unique,
      message: "already has an active session for this game"
    )
  end

  @doc """
  Changeset for completing a session.
  """
  def complete_changeset(session, attrs) do
    attrs =
      attrs
      |> Map.put(:status, :completed)
      |> Map.put_new(:completed_at, DateTime.utc_now() |> DateTime.truncate(:second))

    changeset(session, attrs)
  end
end
