defmodule Medoru.Repo.Migrations.CreateKanjiFallingSessions do
  use Ecto.Migration

  def change do
    create table(:kanji_falling_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "completed"
      add :score, :integer, null: false, default: 0
      add :highest_speed_reached, :integer, null: false, default: 1
      add :lives_remaining, :integer, null: false, default: 0
      add :lives_used, :integer, null: false, default: 0
      add :highest_row_reached, :integer, null: false, default: 0
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end

    create index(:kanji_falling_sessions, [:game_id])
    create index(:kanji_falling_sessions, [:user_id])
    create index(:kanji_falling_sessions, [:game_id, :user_id])
    create index(:kanji_falling_sessions, [:game_id, :score])
  end
end
