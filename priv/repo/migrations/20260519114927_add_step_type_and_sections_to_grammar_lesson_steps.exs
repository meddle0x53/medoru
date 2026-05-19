defmodule Medoru.Repo.Migrations.AddStepTypeAndSectionsToGrammarLessonSteps do
  use Ecto.Migration

  def up do
    alter table(:grammar_lesson_steps) do
      add :step_type, :string, default: "grammar", null: false
      add :explanation_sections, {:array, :string}, default: []
    end

    create index(:grammar_lesson_steps, [:custom_lesson_id, :step_type])
  end

  def down do
    drop index(:grammar_lesson_steps, [:custom_lesson_id, :step_type])

    alter table(:grammar_lesson_steps) do
      remove :step_type
      remove :explanation_sections
    end
  end
end
