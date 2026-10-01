defmodule Medoru.Learning.WordBookShare do
  @moduledoc """
  Schema for pending word book shares between users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Learning.WordBook

  @statuses ["pending", "accepted", "cancelled"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_book_shares" do
    field :status, :string, default: "pending"

    belongs_to :word_book, WordBook
    belongs_to :sender, User
    belongs_to :recipient, User

    timestamps()
  end

  @doc false
  def changeset(word_book_share, attrs) do
    word_book_share
    |> cast(attrs, [:word_book_id, :sender_id, :recipient_id, :status])
    |> validate_required([:word_book_id, :sender_id, :recipient_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:word_book_id)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:recipient_id)
  end

  @doc """
  Changeset for accepting or cancelling a share.
  """
  def status_changeset(word_book_share, status) do
    word_book_share
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end
end
