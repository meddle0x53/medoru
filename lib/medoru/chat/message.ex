defmodule Medoru.Chat.Message do
  @moduledoc """
  Schema for an encrypted message in a conversation.
  The server stores only ciphertext and IV — plaintext is never visible server-side.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :ciphertext, :binary
    field :iv, :binary
    field :encrypted_at, :utc_datetime

    belongs_to :conversation, Medoru.Chat.Conversation
    belongs_to :sender, Medoru.Accounts.User
    belongs_to :reply_to_message, Medoru.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:ciphertext, :iv, :encrypted_at, :conversation_id, :sender_id, :reply_to_message_id])
    |> validate_required([:ciphertext, :iv, :encrypted_at, :conversation_id, :sender_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:reply_to_message_id)
  end
end
