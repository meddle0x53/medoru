defmodule Medoru.Repo.Migrations.CreateReviewSchedules do
  use Ecto.Migration

  def change do
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
