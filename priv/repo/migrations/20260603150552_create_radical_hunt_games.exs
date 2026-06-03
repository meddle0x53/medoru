defmodule Medoru.Repo.Migrations.CreateRadicalHuntGames do
  use Ecto.Migration

  def change do
    create table(:radical_hunt_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :radical, :string, null: false
      add :timeout_seconds, :integer, default: 120, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:radical_hunt_games, [:game_id])
  end
end
