defmodule Medoru.Repo.Migrations.AddAlternativeFormsToWordConjugations do
  use Ecto.Migration

  def change do
    alter table(:word_conjugations) do
      add_if_not_exists :alternative_forms, {:array, :string}, default: [], null: false
    end

    create_if_not_exists index(:word_conjugations, [:alternative_forms], using: :gin)
  end
end
