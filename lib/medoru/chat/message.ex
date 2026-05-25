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
    field :content, :string
    field :is_deleted, :boolean, default: false
    field :edited_at, :utc_datetime
    field :attachment_path, :string
    field :attachment_type, :string
    field :duration_seconds, :integer

    belongs_to :conversation, Medoru.Chat.Conversation
    belongs_to :sender, Medoru.Accounts.User
    belongs_to :reply_to_message, Medoru.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :ciphertext,
      :iv,
      :encrypted_at,
      :content,
      :is_deleted,
      :edited_at,
      :attachment_path,
      :attachment_type,
      :duration_seconds,
      :conversation_id,
      :sender_id,
      :reply_to_message_id
    ])
    |> validate_required([:conversation_id, :sender_id])
    |> validate_content_or_ciphertext()
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:reply_to_message_id)
  end

  defp validate_content_or_ciphertext(changeset) do
    content = get_field(changeset, :content)
    ciphertext = get_field(changeset, :ciphertext)

    if is_nil(content) and is_nil(ciphertext) do
      add_error(changeset, :content, "must provide either content or ciphertext")
    else
      changeset
    end
  end
end
