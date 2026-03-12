defmodule Medoru.Repo.Migrations.CreateClassroomTests do
  use Ecto.Migration

  def change do
    create table(:classroom_tests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "active"
      add :published_at, :utc_datetime_usec
      add :unpublished_at, :utc_datetime_usec
      add :due_date, :utc_datetime
      add :max_attempts, :integer
      add :settings, :map, default: %{}
      add :publish_count, :integer, default: 1

      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :test_id, references(:tests, type: :binary_id, on_delete: :delete_all), null: false

      add :published_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint: a test can only be published once per classroom
    create unique_index(:classroom_tests, [:classroom_id, :test_id])

    # Indexes for common queries
    create index(:classroom_tests, [:classroom_id, :status])
    create index(:classroom_tests, [:test_id])
    create index(:classroom_tests, [:published_by_id])
    create index(:classroom_tests, [:due_date])
  end
end
