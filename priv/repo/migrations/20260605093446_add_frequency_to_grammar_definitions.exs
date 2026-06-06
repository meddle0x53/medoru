defmodule Medoru.Repo.Migrations.AddFrequencyToGrammarDefinitions do
  use Ecto.Migration

  def change do
    alter table(:grammar_definitions) do
      add :frequency, :integer, default: 1000, null: false
    end
  end
end
