defmodule Medoru.Gamification.UserBadge do
  @moduledoc """
  Join table tracking which users have earned which badges.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Gamification.Badge

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_badges" do
    field :awarded_at, :utc_datetime
    field :is_featured, :boolean, default: false

    belongs_to :user, User
    belongs_to :badge, Badge, type: :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_badge, attrs) do
    user_badge
    |> cast(attrs, [:user_id, :badge_id, :awarded_at, :is_featured])
    |> validate_required([:user_id, :badge_id, :awarded_at])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:badge_id)
    |> unique_constraint([:user_id, :badge_id], name: :user_badges_user_id_badge_id_index)
  end
end
