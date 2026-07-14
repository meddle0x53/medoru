defmodule Medoru.Repo.Migrations.AddKanjiComponents do
  use Ecto.Migration

  def up do
    alter table(:kanji) do
      add :components, {:array, :string}, default: []
    end

    execute("CREATE INDEX IF NOT EXISTS kanji_components_index ON kanji USING GIN (components)")
  end

  def down do
    execute("DROP INDEX IF EXISTS kanji_components_index")

    alter table(:kanji) do
      remove :components
    end
  end
end
