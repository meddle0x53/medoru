defmodule Medoru.Repo.Migrations.CreateWordsFallingGames do
  use Ecto.Migration

  def change do
    create table(:words_falling_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :initial_speed, :integer, null: false, default: 1
      add :speed_increase_threshold, :integer, null: false, default: 50
      add :lives, :integer, null: false, default: 3
      add :extra_life_threshold, :integer, null: false, default: 100
      add :selected_words, {:array, :binary_id}, null: false, default: []
      add :word_points, :map, null: false, default: %{}
      add :game_mode, :integer, null: false, default: 0
      add :keyboard_type, :string, null: false, default: "latin"
      add :word_colors, :map, null: false, default: %{}
      add :background_image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:words_falling_games, [:game_id])
  end
end
