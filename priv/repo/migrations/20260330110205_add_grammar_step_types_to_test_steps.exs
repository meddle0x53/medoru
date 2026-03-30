defmodule Medoru.Repo.Migrations.AddGrammarStepTypesToTestSteps do
  use Ecto.Migration

  def up do
    # Grammar question types use question_data JSONB for flexible storage:
    # Type 1 (sentence_validation): {grammar_pattern: [...], show_pattern: boolean, attempts: [], max_attempts: 5}
    # Type 2 (conjugation): {base_word: "...", target_form: "...", word_type: "verb|adjective"}
    # Type 3 (conjugation_multichoice): {base_word: "...", target_form: "...", options: [...]}
    # Type 4 (word_order): {words: [...], correct_order: [...]}

    # Add max_attempts for grammar type 1 steps
    alter table(:test_steps) do
      add :max_attempts, :integer, default: 5
    end

    # Add index for efficient lookup of grammar steps
    create index(:test_steps, [:step_type, :question_type])
  end

  def down do
    drop index(:test_steps, [:step_type, :question_type])

    alter table(:test_steps) do
      remove :max_attempts
    end
  end
end
