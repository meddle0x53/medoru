defmodule Medoru.Accounts.UserStats do
  @moduledoc """
  User aggregate statistics schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_stats" do
    field :total_kanji_learned, :integer, default: 0
    field :total_words_learned, :integer, default: 0
    field :current_streak, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :total_tests_completed, :integer, default: 0
    field :total_duels_played, :integer, default: 0
    field :total_duels_won, :integer, default: 0
    field :xp, :integer, default: 0
    field :level, :integer, default: 1

    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stats, attrs) do
    stats
    |> cast(attrs, [
      :total_kanji_learned,
      :total_words_learned,
      :current_streak,
      :longest_streak,
      :total_tests_completed,
      :total_duels_played,
      :total_duels_won,
      :xp,
      :level
    ])
    |> validate_number(:total_kanji_learned, greater_than_or_equal_to: 0)
    |> validate_number(:total_words_learned, greater_than_or_equal_to: 0)
    |> validate_number(:current_streak, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> validate_number(:total_tests_completed, greater_than_or_equal_to: 0)
    |> validate_number(:total_duels_played, greater_than_or_equal_to: 0)
    |> validate_number(:total_duels_won, greater_than_or_equal_to: 0)
    |> validate_number(:xp, greater_than_or_equal_to: 0)
    |> validate_number(:level, greater_than_or_equal_to: 1)
  end
end
