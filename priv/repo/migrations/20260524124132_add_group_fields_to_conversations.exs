defmodule Medoru.Repo.Migrations.AddGroupFieldsToConversations do
  use Ecto.Migration

  def up do
    alter table(:conversations) do
      add :title, :string
      add :is_group, :boolean, default: false, null: false
    end

    # Remove the old encryption_key_id if it exists
    drop_if_exists index(:conversations, [:encryption_key_id])

    alter table(:conversations) do
      remove_if_exists :encryption_key_id, :string
    end
  end

  def down do
    alter table(:conversations) do
      add :encryption_key_id, :string
      remove :title
      remove :is_group
    end
  end
end
