defmodule Medoru.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def up do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :encryption_key_id, :string
      add :started_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end
  end

  def down do
    drop table(:conversations)
  end
end
