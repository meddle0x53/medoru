defmodule Medoru.Chat.Conversation do
  @moduledoc """
  Schema for a conversation between users (1:1 or group).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "conversations" do
    field :title, :string
    field :is_group, :boolean, default: false
    field :started_at, :utc_datetime

    belongs_to :classroom, Medoru.Classrooms.Classroom, type: :binary_id

    has_many :participants, Medoru.Chat.ConversationParticipant
    has_many :messages, Medoru.Chat.Message
    has_many :conversation_keys, Medoru.Chat.ConversationKey

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :is_group, :started_at, :classroom_id])
    |> validate_required([:started_at])
  end
end
