defmodule Medoru.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :type, :string, null: false
      add :title, :string, null: false
      add :message, :string, null: false
      add :read_at, :utc_datetime
      add :data, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:inserted_at])
  end
end
