defmodule Medoru.Repo.Migrations.CreateMemoryCardGameWords do
  use Ecto.Migration

  def change do
    create table(:memory_card_game_words, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :memory_card_game_id, references(:memory_card_games, type: :binary_id, on_delete: :delete_all), null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false
      add :points, :integer, default: 1
      add :position, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:memory_card_game_words, [:memory_card_game_id])
    create unique_index(:memory_card_game_words, [:memory_card_game_id, :word_id])
  end
end
