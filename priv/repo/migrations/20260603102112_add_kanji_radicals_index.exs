defmodule Medoru.Repo.Migrations.AddKanjiRadicalsIndex do
  use Ecto.Migration

  def up do
    # GIN index for fast array membership queries:
    #   SELECT * FROM kanji WHERE '水' = ANY(radicals);
    execute("CREATE INDEX IF NOT EXISTS kanji_radicals_index ON kanji USING GIN (radicals)")
  end

  def down do
    execute("DROP INDEX IF EXISTS kanji_radicals_index")
  end
end
