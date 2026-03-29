defmodule Medoru.Repo.Migrations.CreateWordConjugations do
  use Ecto.Migration

  def change do
    create table(:word_conjugations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conjugated_form, :string, null: false
      add :reading, :string

      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false

      add :grammar_form_id, references(:grammar_forms, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:word_conjugations, [:word_id])
    create index(:word_conjugations, [:grammar_form_id])
    create index(:word_conjugations, [:conjugated_form])
    create unique_index(:word_conjugations, [:word_id, :grammar_form_id])
  end
end
