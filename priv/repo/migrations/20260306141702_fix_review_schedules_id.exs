defmodule Medoru.Repo.Migrations.FixReviewSchedulesId do
  use Ecto.Migration

  def up do
    # Drop existing table and indexes
    drop_if_exists index(:review_schedules, [:user_id, :user_progress_id])
    drop_if_exists index(:review_schedules, [:next_review_at])
    drop_if_exists index(:review_schedules, [:user_id, :next_review_at])
    drop_if_exists table(:review_schedules)

    # Recreate with correct id type
    create table(:review_schedules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :next_review_at, :utc_datetime
      add :interval, :integer, null: false, default: 1
      add :ease_factor, :float, null: false, default: 2.5
      add :repetitions, :integer, null: false, default: 0

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :user_progress_id, references(:user_progress, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:review_schedules, [:user_id, :user_progress_id])
    create index(:review_schedules, [:next_review_at])
    create index(:review_schedules, [:user_id, :next_review_at])
  end

  def down do
    drop_if_exists index(:review_schedules, [:user_id, :user_progress_id])
    drop_if_exists index(:review_schedules, [:next_review_at])
    drop_if_exists index(:review_schedules, [:user_id, :next_review_at])
    drop_if_exists table(:review_schedules)

    # Recreate original (with wrong id type)
    create table(:review_schedules) do
      add :next_review_at, :utc_datetime
      add :interval, :integer, null: false, default: 1
      add :ease_factor, :float, null: false, default: 2.5
      add :repetitions, :integer, null: false, default: 0

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :user_progress_id, references(:user_progress, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:review_schedules, [:user_id, :user_progress_id])
    create index(:review_schedules, [:next_review_at])
    create index(:review_schedules, [:user_id, :next_review_at])
  end
end
