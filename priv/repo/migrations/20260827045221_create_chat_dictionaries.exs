defmodule Medoru.Repo.Migrations.CreateChatDictionaries do
  use Ecto.Migration

  def change do
    create table(:chat_dictionaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: true

      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_dictionaries, [:user_id],
             where: "conversation_id IS NULL",
             name: :chat_dictionaries_user_id_main_index
           )

    create unique_index(:chat_dictionaries, [:user_id, :conversation_id],
             where: "conversation_id IS NOT NULL",
             name: :chat_dictionaries_user_id_conversation_id_index
           )

    create index(:chat_dictionaries, [:user_id], name: :chat_dictionaries_user_id_lookup_index)
  end
end
