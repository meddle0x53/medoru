defmodule Medoru.Repo.Migrations.CreateKanjiFallingGames do
  use Ecto.Migration

  def change do
    create table(:kanji_falling_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :initial_speed, :integer, null: false, default: 1
      add :speed_increase_threshold, :integer, null: false, default: 50
      add :lives, :integer, null: false, default: 3
      add :extra_life_threshold, :integer, null: false, default: 100
      add :points_per_kanji, :integer, null: false, default: 1
      add :selected_kanji, {:array, :string}, null: false, default: []
      add :reading_type, :string, null: false, default: "any"
      add :keyboard_type, :string, null: false, default: "hiragana"
      add :kanji_colors, :map, null: false, default: %{}
      add :background_image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kanji_falling_games, [:game_id])
  end
end
