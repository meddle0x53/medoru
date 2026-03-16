defmodule Medoru.Repo.Migrations.AddTranslationsToContent do
  use Ecto.Migration

  def up do
    # Add translations JSONB column to kanji table
    alter table(:kanji) do
      add :translations, :map, default: %{}
    end

    # Add translations JSONB column to words table
    alter table(:words) do
      add :translations, :map, default: %{}
    end

    # Add translations JSONB column to lessons table
    alter table(:lessons) do
      add :translations, :map, default: %{}
    end

    # Create index for efficient querying by translation keys
    execute "CREATE INDEX IF NOT EXISTS kanji_translations_index ON kanji USING GIN(translations)"
    execute "CREATE INDEX IF NOT EXISTS words_translations_index ON words USING GIN(translations)"

    execute "CREATE INDEX IF NOT EXISTS lessons_translations_index ON lessons USING GIN(translations)"
  end

  def down do
    execute "DROP INDEX IF EXISTS kanji_translations_index"
    execute "DROP INDEX IF EXISTS words_translations_index"
    execute "DROP INDEX IF EXISTS lessons_translations_index"

    alter table(:kanji) do
      remove :translations
    end

    alter table(:words) do
      remove :translations
    end

    alter table(:lessons) do
      remove :translations
    end
  end
end
