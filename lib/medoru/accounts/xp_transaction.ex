defmodule Medoru.Accounts.XpTransaction do
  @moduledoc """
  Schema for XP transaction audit log.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "xp_transactions" do
    belongs_to :user, Medoru.Accounts.User
    field :amount, :integer
    field :source_type, :string
    field :source_id, :string
    field :description, :string
    field :awarded_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(xp_transaction, attrs) do
    xp_transaction
    |> cast(attrs, [:user_id, :amount, :source_type, :source_id, :description, :awarded_at])
    |> validate_required([:user_id, :amount, :source_type, :awarded_at])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end
end
