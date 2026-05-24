defmodule Medoru.Repo.Migrations.CreateConversationParticipants do
  use Ecto.Migration

  def up do
    create table(:conversation_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime
      add :is_typing, :boolean, default: false, null: false
      add :has_left, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversation_participants, [:conversation_id, :user_id])
    create index(:conversation_participants, [:user_id])
  end

  def down do
    drop table(:conversation_participants)
  end
end
