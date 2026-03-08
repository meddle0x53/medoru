defmodule Medoru.Repo.Migrations.CreateTestSessions do
  use Ecto.Migration

  def change do
    create table(:test_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "started"
      add :score, :integer, null: false, default: 0
      add :total_possible, :integer, null: false, default: 0
      add :percentage, :float
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :time_spent_seconds, :integer, null: false, default: 0
      add :current_step_index, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :test_id, references(:tests, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:test_sessions, [:user_id])
    create index(:test_sessions, [:test_id])
    create index(:test_sessions, [:status])
    create index(:test_sessions, [:user_id, :status])
    create index(:test_sessions, [:user_id, :test_id])
    create index(:test_sessions, [:inserted_at])
    create index(:test_sessions, [:completed_at])
  end
end
