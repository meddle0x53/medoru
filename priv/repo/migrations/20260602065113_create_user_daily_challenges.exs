defmodule Medoru.Repo.Migrations.CreateUserDailyChallenges do
  use Ecto.Migration

  def change do
    create table(:user_daily_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :challenge_type, :string, null: false
      add :date, :date, null: false
      add :completed_at, :utc_datetime
      add :xp_awarded, :integer, default: 0
      add :score, :integer
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:user_daily_challenges, [:user_id])
    create index(:user_daily_challenges, [:user_id, :date])
    create unique_index(:user_daily_challenges, [:user_id, :challenge_type, :date])
  end
end
