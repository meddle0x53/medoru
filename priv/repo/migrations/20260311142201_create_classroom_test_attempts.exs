defmodule Medoru.Repo.Migrations.CreateClassroomTestAttempts do
  use Ecto.Migration

  def change do
    create table(:classroom_test_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :test_id, references(:tests, type: :binary_id, on_delete: :nilify_all), null: false
      add :test_session_id, references(:test_sessions, type: :binary_id, on_delete: :nilify_all)

      # Scoring
      add :score, :integer, null: false, default: 0
      add :max_score, :integer, null: false
      add :points_earned, :integer, null: false, default: 0

      # Timing - crucial for rankings
      add :time_limit_seconds, :integer, null: false
      add :time_spent_seconds, :integer, null: false, default: 0
      add :time_remaining_seconds, :integer, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :completed_at, :utc_datetime_usec

      # Status and completion
      # in_progress, completed, timed_out
      add :status, :string, null: false, default: "in_progress"
      add :auto_submitted, :boolean, default: false

      # Reset tracking
      add :reset_count, :integer, default: 0
      add :reset_at, :utc_datetime_usec
      add :reset_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # For ranking queries
      add :ranking_score, :decimal, precision: 15, scale: 4

      timestamps(type: :utc_datetime_usec)
    end

    # Core indexes
    create index(:classroom_test_attempts, [:classroom_id])
    create index(:classroom_test_attempts, [:user_id])
    create index(:classroom_test_attempts, [:test_id])
    create index(:classroom_test_attempts, [:completed_at])

    # Unique constraint - one attempt per user per test (unless reset)
    create index(:classroom_test_attempts, [:classroom_id, :test_id, :user_id],
             unique: true,
             where: "reset_count = 0"
           )

    # Leaderboard indexes
    create index(
             :classroom_test_attempts,
             [:classroom_id, :test_id, :points_earned, :time_remaining_seconds],
             name: :idx_test_leaderboard
           )

    create index(:classroom_test_attempts, [:classroom_id, :points_earned, :time_spent_seconds],
             name: :idx_classroom_leaderboard
           )
  end
end
