defmodule Medoru.Repo.Migrations.CreateUserRelations do
  use Ecto.Migration

  def change do
    create table(:user_relations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :target_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :relationship_type, :string
      add :description, :text
      add :address_style, :string
      add :nicknames, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_relations, [:user_id, :target_user_id])
    create index(:user_relations, [:user_id])
    create index(:user_relations, [:target_user_id])
  end
end
