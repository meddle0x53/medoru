defmodule Medoru.Learning.UserDailyChallenge do
  @moduledoc """
  Tracks completion of daily challenges per user per day.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User

  @challenge_types [
    "daily_test",
    "daily_kanji",
    "daily_cards",
    "daily_radical_hunt",
    "ouroboros_run"
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_daily_challenges" do
    field :challenge_type, :string
    field :date, :date
    field :completed_at, :utc_datetime
    field :xp_awarded, :integer, default: 0
    field :score, :integer
    field :metadata, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [
      :user_id,
      :challenge_type,
      :date,
      :completed_at,
      :xp_awarded,
      :score,
      :metadata
    ])
    |> validate_required([:user_id, :challenge_type, :date])
    |> validate_inclusion(:challenge_type, @challenge_types)
    |> validate_number(:xp_awarded, greater_than_or_equal_to: 0)
    |> validate_number(:score, greater_than_or_equal_to: 0)
  end

  def challenge_types, do: @challenge_types
end
