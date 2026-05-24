defmodule Medoru.Repo.Migrations.AddJoinedAtToParticipants do
  use Ecto.Migration

  def up do
    alter table(:conversation_participants) do
      add :joined_at, :utc_datetime
    end
  end

  def down do
    alter table(:conversation_participants) do
      remove :joined_at
    end
  end
end
