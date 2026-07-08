defmodule Medoru.Learning.WordSetShare do
  @moduledoc """
  Schema for pending word set shares between users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Learning.WordSet

  @statuses ["pending", "accepted", "cancelled"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_set_shares" do
    field :status, :string, default: "pending"

    belongs_to :word_set, WordSet
    belongs_to :sender, User
    belongs_to :recipient, User

    timestamps()
  end

  @doc false
  def changeset(word_set_share, attrs) do
    word_set_share
    |> cast(attrs, [:word_set_id, :sender_id, :recipient_id, :status])
    |> validate_required([:word_set_id, :sender_id, :recipient_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:word_set_id)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:recipient_id)
  end

  @doc """
  Changeset for accepting or cancelling a share.
  """
  def status_changeset(word_set_share, status) do
    word_set_share
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end
end
