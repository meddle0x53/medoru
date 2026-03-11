defmodule Medoru.Repo.Migrations.CreateClassroomLessonProgress do
  use Ecto.Migration

  def change do
    create table(:classroom_lesson_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false

      # Progress tracking
      # not_started, in_progress, completed
      add :status, :string, null: false, default: "not_started"
      add :progress_percent, :integer, default: 0

      # Points earned from this lesson (through lesson test)
      add :points_earned, :integer, default: 0

      # Completion tracking
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      # Lesson test reference
      add :test_session_id, references(:test_sessions, type: :binary_id, on_delete: :nilify_all)
      add :test_score, :integer
      add :test_max_score, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create index(:classroom_lesson_progress, [:classroom_id])
    create index(:classroom_lesson_progress, [:user_id])
    create index(:classroom_lesson_progress, [:lesson_id])
    create index(:classroom_lesson_progress, [:status])
    create index(:classroom_lesson_progress, [:completed_at])

    # Unique constraint - one progress record per user per lesson per classroom
    create unique_index(:classroom_lesson_progress, [:classroom_id, :user_id, :lesson_id])

    # Leaderboard index
    create index(:classroom_lesson_progress, [:classroom_id, :points_earned, :completed_at])
  end
end
