defmodule Medoru.Accounts.User do
  @moduledoc """
  User schema for OAuth authentication.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :provider, :string
    field :provider_uid, :string
    field :name, :string
    field :avatar_url, :string

    has_one :profile, Medoru.Accounts.UserProfile
    has_one :stats, Medoru.Accounts.UserStats

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :provider, :provider_uid, :name, :avatar_url])
    |> validate_required([:email, :provider, :provider_uid])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:provider, ["google"])
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_uid],
      name: :users_provider_provider_uid_index,
      message: "account already exists"
    )
  end
end
