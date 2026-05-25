defmodule Medoru.Repo.Migrations.AddConversationArchiving do
  use Ecto.Migration

  def change do
    alter table(:conversation_participants) do
      add :is_archived, :boolean, default: false, null: false
    end

    create index(:conversation_participants, [:user_id, :is_archived])
  end
end
