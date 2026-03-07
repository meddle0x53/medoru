defmodule Medoru.Repo.Migrations.CreateUserBadges do
  use Ecto.Migration

  def change do
    create table(:user_badges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :badge_id, references(:badges, on_delete: :delete_all), null: false
      add :awarded_at, :utc_datetime, null: false
      add :is_featured, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_badges, [:user_id, :badge_id])
    create index(:user_badges, [:user_id])
    create index(:user_badges, [:badge_id])
    create index(:user_badges, [:user_id, :is_featured])
  end
end
