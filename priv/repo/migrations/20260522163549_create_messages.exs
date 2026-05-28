defmodule Medoru.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def up do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id), null: false
      add :ciphertext, :binary, null: false
      add :iv, :binary, null: false
      add :reply_to_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :encrypted_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id, :inserted_at])
    create index(:messages, [:sender_id])
    create index(:messages, [:reply_to_message_id])
  end

  def down do
    drop table(:messages)
  end
end
