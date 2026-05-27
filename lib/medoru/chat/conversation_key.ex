defmodule Medoru.Chat.ConversationKey do
  @moduledoc """
  Schema for storing a conversation's symmetric key encrypted per-user.
  The actual AES key is encrypted with the user's RSA public key.
  The server never sees the unencrypted conversation key.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversation_keys" do
    field :encrypted_key, :binary
    field :key_fingerprint, :string

    belongs_to :conversation, Medoru.Chat.Conversation
    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation_key, attrs) do
    conversation_key
    |> cast(attrs, [:encrypted_key, :key_fingerprint, :conversation_id, :user_id])
    |> validate_required([:encrypted_key, :conversation_id, :user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:conversation_id, :user_id, :key_fingerprint],
      name: :conversation_keys_conversation_id_user_id_key_fingerprint_index,
      message: "key already exists for this user and fingerprint"
    )
  end
end
