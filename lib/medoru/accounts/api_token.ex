defmodule Medoru.Accounts.ApiToken do
  @moduledoc """
  Schema for user API tokens.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_tokens" do
    field :name, :string
    field :token_hash, :string
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:name, :token_hash, :expires_at, :last_used_at, :user_id])
    |> validate_required([:token_hash, :user_id])
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:user_id)
  end
end
