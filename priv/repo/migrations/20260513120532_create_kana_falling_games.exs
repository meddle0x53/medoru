defmodule Medoru.Repo.Migrations.CreateKanaFallingGames do
  use Ecto.Migration

  def change do
    create table(:kana_falling_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :initial_speed, :integer, null: false, default: 1
      add :speed_increase_threshold, :integer, null: false, default: 50
      add :lives, :integer, null: false, default: 3
      add :extra_life_threshold, :integer, null: false, default: 100
      add :points_per_kana, :integer, null: false, default: 1
      add :selected_kana, {:array, :string}, null: false, default: []
      add :background_image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kana_falling_games, [:game_id])
  end
end
