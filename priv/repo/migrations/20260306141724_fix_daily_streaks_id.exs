defmodule Medoru.Repo.Migrations.FixDailyStreaksId do
  use Ecto.Migration

  def up do
    # Drop existing table and indexes
    drop_if_exists index(:daily_streaks, [:user_id])
    drop_if_exists index(:daily_streaks, [:last_study_date])
    drop_if_exists table(:daily_streaks)

    # Recreate with correct id type
    create table(:daily_streaks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :current_streak, :integer, null: false, default: 0
      add :longest_streak, :integer, null: false, default: 0
      add :last_study_date, :date
      add :timezone, :string, null: false, default: "UTC"

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_streaks, [:user_id])
    create index(:daily_streaks, [:last_study_date])
  end

  def down do
    drop_if_exists index(:daily_streaks, [:user_id])
    drop_if_exists index(:daily_streaks, [:last_study_date])
    drop_if_exists table(:daily_streaks)

    # Recreate original (with wrong id type)
    create table(:daily_streaks) do
      add :current_streak, :integer, null: false, default: 0
      add :longest_streak, :integer, null: false, default: 0
      add :last_study_date, :date
      add :timezone, :string, null: false, default: "UTC"

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:daily_streaks, [:user_id])
    create index(:daily_streaks, [:last_study_date])
  end
end
