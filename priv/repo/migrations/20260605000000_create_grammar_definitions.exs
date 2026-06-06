defmodule Medoru.Repo.Migrations.CreateGrammarDefinitions do
  use Ecto.Migration

  def change do
    create table(:grammar_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :pattern_elements, {:array, :map}, default: []
      add :word_colors, {:array, :map}, default: []
      add :description, :text
      add :description_bg, :text
      add :description_ja, :text
      add :examples, {:array, :map}, default: []
      add :jlpt_level, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:grammar_definitions, [:title])
    create unique_index(:grammar_definitions, [:slug])
    create index(:grammar_definitions, [:jlpt_level])
  end
end
