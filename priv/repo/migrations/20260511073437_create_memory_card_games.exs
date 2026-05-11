defmodule Medoru.Repo.Migrations.CreateMemoryCardGames do
  use Ecto.Migration

  def change do
    create table(:memory_card_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :board_size, :string, null: false
      add :max_attempts, :integer, null: false
      add :meaning_required_for_collection, :boolean, default: false, null: false
      add :pronunciation_required_for_collection, :boolean, default: false, null: false
      add :meaning_or_pronunciation_required_for_collection, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:memory_card_games, [:game_id])
  end
end
