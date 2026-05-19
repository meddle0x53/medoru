defmodule Medoru.Repo.Migrations.AddTestAndValidationFlagsToGrammarSteps do
  use Ecto.Migration

  def up do
    alter table(:grammar_lesson_steps) do
      add :include_in_test, :boolean, default: false, null: false
      add :allows_student_validation, :boolean, default: false, null: false
    end
  end

  def down do
    alter table(:grammar_lesson_steps) do
      remove :include_in_test
      remove :allows_student_validation
    end
  end
end
