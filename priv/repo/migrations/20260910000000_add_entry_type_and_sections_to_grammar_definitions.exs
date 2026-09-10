defmodule Medoru.Repo.Migrations.AddEntryTypeAndSectionsToGrammarDefinitions do
  use Ecto.Migration

  def up do
    alter table(:grammar_definitions) do
      add :entry_type, :string, null: false, default: "pattern"
      add :explanation_sections, {:array, :text}, null: false, default: []
    end
  end

  def down do
    alter table(:grammar_definitions) do
      remove :explanation_sections
      remove :entry_type
    end
  end
end
