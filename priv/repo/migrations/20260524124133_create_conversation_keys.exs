defmodule Medoru.Repo.Migrations.CreateConversationKeys do
  use Ecto.Migration

  def up do
    create table(:conversation_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :encrypted_key, :binary, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversation_keys, [:conversation_id, :user_id])
    create index(:conversation_keys, [:conversation_id])
    create index(:conversation_keys, [:user_id])
  end

  def down do
    drop table(:conversation_keys)
  end
end
