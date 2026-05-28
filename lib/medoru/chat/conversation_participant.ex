defmodule Medoru.Chat.ConversationParticipant do
  @moduledoc """
  Schema for a participant in a conversation.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversation_participants" do
    field :last_read_at, :utc_datetime
    field :is_typing, :boolean, default: false
    field :has_left, :boolean, default: false
    field :is_archived, :boolean, default: false
    field :joined_at, :utc_datetime

    belongs_to :conversation, Medoru.Chat.Conversation
    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :last_read_at,
      :is_typing,
      :has_left,
      :is_archived,
      :joined_at,
      :conversation_id,
      :user_id
    ])
    |> validate_required([:conversation_id, :user_id])
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:user_id)
  end
end
