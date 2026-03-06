defmodule Medoru.Learning.DailyStreak do
  @moduledoc """
  Tracks user's daily study streak for consistent learning habits.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "daily_streaks" do
    field :current_streak, :integer, default: 0
    field :longest_streak, :integer, default: 0
    field :last_study_date, :date
    field :timezone, :string, default: "UTC"

    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(daily_streak, attrs) do
    daily_streak
    |> cast(attrs, [:current_streak, :longest_streak, :last_study_date, :timezone, :user_id])
    |> validate_required([:current_streak, :longest_streak, :timezone])
    |> validate_number(:current_streak, greater_than_or_equal_to: 0)
    |> validate_number(:longest_streak, greater_than_or_equal_to: 0)
    |> validate_length(:timezone, min: 1, max: 100)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end
end
