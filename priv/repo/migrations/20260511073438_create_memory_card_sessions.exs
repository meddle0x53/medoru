defmodule Medoru.Repo.Migrations.CreateMemoryCardSessions do
  use Ecto.Migration

  def change do
    create table(:memory_card_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "in_progress"
      add :score, :integer, default: 0
      add :attempts_used, :integer, default: 0
      add :max_attempts, :integer, null: false
      add :cards_state, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:memory_card_sessions, [:game_id])
    create index(:memory_card_sessions, [:game_id, :user_id])
    create unique_index(:memory_card_sessions, [:game_id, :user_id], where: "status = 'in_progress'", name: :memory_card_sessions_in_progress_unique)
  end
end
