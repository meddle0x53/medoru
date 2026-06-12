defmodule Medoru.Social.Follow do
  @moduledoc """
  Schema for one-way user follows.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "follows" do
    belongs_to :follower, Medoru.Accounts.User
    belongs_to :following, Medoru.Accounts.User
    field :followed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :following_id, :followed_at])
    |> validate_required([:follower_id, :following_id, :followed_at])
    |> unique_constraint([:follower_id, :following_id])
    |> foreign_key_constraint(:follower_id)
    |> foreign_key_constraint(:following_id)
    |> check_constraint(:follower_id,
      name: :cannot_follow_self,
      message: "cannot follow yourself"
    )
  end
end
