defmodule Medoru.Repo.Migrations.CreateUserStats do
  use Ecto.Migration

  def change do
    create table(:user_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :total_kanji_learned, :integer, default: 0, null: false
      add :total_words_learned, :integer, default: 0, null: false
      add :current_streak, :integer, default: 0, null: false
      add :longest_streak, :integer, default: 0, null: false
      add :total_tests_completed, :integer, default: 0, null: false
      add :total_duels_played, :integer, default: 0, null: false
      add :total_duels_won, :integer, default: 0, null: false
      add :xp, :integer, default: 0, null: false
      add :level, :integer, default: 1, null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_stats, [:user_id])
  end
end
