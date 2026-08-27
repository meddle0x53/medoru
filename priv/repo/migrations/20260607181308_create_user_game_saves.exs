defmodule Medoru.Repo.Migrations.CreateUserGameSaves do
  use Ecto.Migration

  def change do
    create table(:user_game_saves, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :save_data, :map, null: false, default: %{}
      add :version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_game_saves, [:user_id])
  end
end
