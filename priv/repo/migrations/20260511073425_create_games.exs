defmodule Medoru.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :type, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :max_players, :integer, default: 1
      add :settings, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:classroom_id])
    create index(:games, [:classroom_id, :status])
    create index(:games, [:classroom_id, :type])
  end
end
