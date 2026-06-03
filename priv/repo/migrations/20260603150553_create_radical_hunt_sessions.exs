defmodule Medoru.Repo.Migrations.CreateRadicalHuntSessions do
  use Ecto.Migration

  def change do
    create table(:radical_hunt_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "completed", null: false
      add :score, :integer, default: 0, null: false
      add :kanji_found, {:array, :string}, default: []
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end

    create index(:radical_hunt_sessions, [:game_id])
    create index(:radical_hunt_sessions, [:user_id])
    create index(:radical_hunt_sessions, [:game_id, :user_id])
  end
end
