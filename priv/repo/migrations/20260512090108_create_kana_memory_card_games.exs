defmodule Medoru.Repo.Migrations.CreateKanaMemoryCardGames do
  use Ecto.Migration

  def change do
    create table(:kana_memory_card_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :board_size, :string, null: false
      add :max_attempts, :integer, null: false
      add :require_reading, :boolean, default: false, null: false
      add :selected_kana, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kana_memory_card_games, [:game_id])
  end
end
