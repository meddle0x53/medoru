defmodule Medoru.Repo.Migrations.AddWordTypeToWords do
  use Ecto.Migration

  def change do
    # Create enum type for word types
    execute "CREATE TYPE word_type AS ENUM ('noun', 'verb', 'adjective', 'adverb', 'particle', 'pronoun', 'counter', 'expression', 'other')",
            "DROP TYPE word_type"

    alter table(:words) do
      add :word_type, :word_type, null: false, default: "other"
    end

    create index(:words, [:word_type])
  end
end
