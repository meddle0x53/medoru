defmodule Medoru.Dictionaries.ChatDictionary do
  @moduledoc """
  Schema for a user's dictionary for a specific chat, or the main dictionary
  when conversation_id is nil.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_dictionaries" do
    field :enabled, :boolean, default: true

    belongs_to :user, Medoru.Accounts.User
    belongs_to :conversation, Medoru.Chat.Conversation, type: :binary_id
    has_many :entries, Medoru.Dictionaries.DictionaryEntry, foreign_key: :dictionary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_dictionary, attrs) do
    chat_dictionary
    |> cast(attrs, [:user_id, :conversation_id, :enabled])
    |> validate_required([:user_id, :enabled])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:conversation_id)
  end
end
