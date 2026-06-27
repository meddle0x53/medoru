defmodule Medoru.Repo.Migrations.ChangeGrammarLessonStepExplanationSectionsToText do
  use Ecto.Migration

  def up do
    alter table(:grammar_lesson_steps) do
      modify :explanation_sections, {:array, :text}
    end
  end

  def down do
    alter table(:grammar_lesson_steps) do
      modify :explanation_sections, {:array, :string}
    end
  end
end
