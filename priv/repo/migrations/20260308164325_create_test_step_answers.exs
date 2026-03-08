defmodule Medoru.Repo.Migrations.CreateTestStepAnswers do
  use Ecto.Migration

  def change do
    create table(:test_step_answers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :step_index, :integer, null: false
      add :answer, :string, null: false
      add :is_correct, :boolean, null: false
      add :points_earned, :integer, null: false, default: 0
      add :time_spent_seconds, :integer, null: false, default: 0
      add :attempts, :integer, null: false, default: 1
      add :hints_used, :integer, null: false, default: 0
      add :answered_at, :utc_datetime
      add :metadata, :map, null: false, default: %{}

      add :test_session_id, references(:test_sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :test_step_id, references(:test_steps, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:test_step_answers, [:test_session_id])
    create index(:test_step_answers, [:test_step_id])
    create index(:test_step_answers, [:is_correct])
    create unique_index(:test_step_answers, [:test_session_id, :step_index])
  end
end
