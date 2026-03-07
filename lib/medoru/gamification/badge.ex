defmodule Medoru.Gamification.Badge do
  @moduledoc """
  Schema for badges/achievements that users can earn.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "badges" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :color, :string, default: "blue"

    field :criteria_type, Ecto.Enum,
      values: [:manual, :streak, :kanji_count, :words_count, :lessons_completed, :daily_reviews]

    field :criteria_value, :integer
    field :order_index, :integer, default: 0

    has_many :user_badges, Medoru.Gamification.UserBadge

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [
      :name,
      :description,
      :icon,
      :color,
      :criteria_type,
      :criteria_value,
      :order_index
    ])
    |> validate_required([:name, :description, :icon])
    |> validate_length(:name, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_length(:icon, max: 50)
    |> validate_inclusion(:color, ~w(blue green yellow orange red purple pink indigo emerald))
    |> unique_constraint(:name)
  end
end
