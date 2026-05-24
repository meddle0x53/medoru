defmodule Medoru.Repo.Migrations.CreateUserBlocks do
  use Ecto.Migration

  def up do
    create table(:user_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :blocker_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :blocked_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :reason, :string
      add :blocked_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_blocks, [:blocker_id, :blocked_id])
    create index(:user_blocks, [:blocker_id])
    create index(:user_blocks, [:blocked_id])
  end

  def down do
    drop table(:user_blocks)
  end
end
