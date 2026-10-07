defmodule Medoru.Challenges.KanjiMasterScore do
  @moduledoc """
  A user's best Kanji Master score plus their chosen leaderboard identity.

  One row per user (upsert by `user_id`). The score only ever goes up;
  the identity (`display_mode`/`anonymous_name`) may be changed every run.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @display_modes ["linked", "anonymous"]

  schema "kanji_master_scores" do
    field :score, :integer, default: 0
    field :display_mode, :string, default: "linked"
    field :anonymous_name, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def display_modes, do: @display_modes

  def changeset(score, attrs) do
    score
    |> cast(attrs, [:score, :display_mode, :anonymous_name])
    |> validate_required([:score, :display_mode])
    |> validate_inclusion(:display_mode, @display_modes)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_anonymous_name()
    |> unique_constraint(:user_id)
  end

  defp validate_anonymous_name(changeset) do
    if get_field(changeset, :display_mode) == "anonymous" do
      validate_required(changeset, [:anonymous_name])
    else
      changeset
    end
  end
end
