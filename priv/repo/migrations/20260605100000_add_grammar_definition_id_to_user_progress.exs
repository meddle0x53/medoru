defmodule Medoru.Repo.Migrations.AddGrammarDefinitionIdToUserProgress do
  use Ecto.Migration

  def change do
    alter table(:user_progress) do
      add :grammar_definition_id,
          references(:grammar_definitions, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:user_progress, [:user_id, :grammar_definition_id],
             where: "grammar_definition_id IS NOT NULL",
             name: :user_progress_user_id_grammar_definition_id_index
           )
  end
end
