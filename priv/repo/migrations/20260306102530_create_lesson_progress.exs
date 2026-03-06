defmodule Medoru.Repo.Migrations.CreateLessonProgress do
  use Ecto.Migration

  def change do
    create table(:lesson_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "started"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :progress_percentage, :integer, null: false, default: 0

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:lesson_progress, [:user_id])
    create index(:lesson_progress, [:lesson_id])
    create index(:lesson_progress, [:user_id, :status])

    # Unique constraint - user can only have one progress per lesson
    create unique_index(:lesson_progress, [:user_id, :lesson_id],
             name: :lesson_progress_user_id_lesson_id_index
           )
  end
end
