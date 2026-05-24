defmodule Medoru.Encryption.UserPublicKey do
  @moduledoc """
  Schema for storing a user's RSA public key for E2E encryption.
  Private keys are never stored on the server.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_public_keys" do
    field :key_version, :string
    field :public_key_spki, :binary
    field :algorithm, :string, default: "RSA-OAEP-2048"
    field :is_active, :boolean, default: true

    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_public_key, attrs) do
    user_public_key
    |> cast(attrs, [:key_version, :public_key_spki, :algorithm, :is_active, :user_id])
    |> validate_required([:key_version, :public_key_spki, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
