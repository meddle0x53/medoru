defmodule Medoru.Repo.Migrations.CreateUserTags do
  use Ecto.Migration

  def change do
    create table(:user_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_tags, [:user_id, :tag_id])
    create index(:user_tags, [:tag_id])
  end
end
