defmodule Medoru.Repo.Migrations.EnsureGrammarExplanationText do
  use Ecto.Migration

  def up do
    alter table(:grammar_lesson_steps) do
      modify :explanation, :text
    end
  end

  def down do
    alter table(:grammar_lesson_steps) do
      modify :explanation, :string
    end
  end
end
