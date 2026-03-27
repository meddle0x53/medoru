defmodule Medoru.Repo.Migrations.CreateGrammarForms do
  use Ecto.Migration

  def change do
    create table(:grammar_forms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :word_type, :string, null: false
      add :suffix_pattern, :string
      add :description, :text
      add :examples, {:array, :string}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:grammar_forms, [:name, :word_type])
    create index(:grammar_forms, [:word_type])
  end
end
