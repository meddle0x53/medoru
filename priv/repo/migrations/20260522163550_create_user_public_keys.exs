defmodule Medoru.Repo.Migrations.CreateUserPublicKeys do
  use Ecto.Migration

  def up do
    create table(:user_public_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :key_version, :string, null: false
      add :public_key_spki, :binary, null: false
      add :algorithm, :string, default: "ECDH-P-256"
      add :is_active, :boolean, default: true, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_public_keys, [:user_id, :key_version])
    create index(:user_public_keys, [:user_id, :is_active])
  end

  def down do
    drop table(:user_public_keys)
  end
end
