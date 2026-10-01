defmodule Medoru.Repo.Migrations.CreateWordSetCardGames do
  use Ecto.Migration

  def up do
    create table(:word_set_card_games, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_set_id, references(:word_sets, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :words, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:word_set_card_games, [:word_set_id])
    create index(:word_set_card_games, [:user_id])
  end

  def down do
    drop table(:word_set_card_games)
  end
end
