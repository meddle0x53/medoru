defmodule Medoru.Repo.Migrations.CreateDailyStreaks do
  use Ecto.Migration

  def change do
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
