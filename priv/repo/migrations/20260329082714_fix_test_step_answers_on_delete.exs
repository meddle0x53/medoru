defmodule Medoru.Repo.Migrations.FixTestStepAnswersOnDelete do
  use Ecto.Migration

  def up do
    # Drop the existing foreign key constraint
    drop constraint(:test_step_answers, :test_step_answers_test_step_id_fkey)

    # Recreate it with on_delete: :delete_all
    alter table(:test_step_answers) do
      modify :test_step_id,
             references(:test_steps, type: :binary_id, on_delete: :delete_all),
             null: false
    end
  end

  def down do
    # Revert back to nilify_all
    drop constraint(:test_step_answers, :test_step_answers_test_step_id_fkey)

    alter table(:test_step_answers) do
      modify :test_step_id,
             references(:test_steps, type: :binary_id, on_delete: :nilify_all),
             null: false
    end
  end
end
