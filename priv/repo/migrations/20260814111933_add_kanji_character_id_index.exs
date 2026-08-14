defmodule Medoru.Repo.Migrations.AddKanjiCharacterIdIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists index(:kanji, [:character, :id])
  end

  def down do
    drop_if_exists index(:kanji, [:character, :id])
  end
end
