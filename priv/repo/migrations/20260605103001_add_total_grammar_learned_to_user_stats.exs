defmodule Medoru.Repo.Migrations.AddTotalGrammarLearnedToUserStats do
  use Ecto.Migration

  def change do
    alter table(:user_stats) do
      add :total_grammar_learned, :integer, null: false, default: 0
    end
  end
end
