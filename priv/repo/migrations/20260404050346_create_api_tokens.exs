defmodule Medoru.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:api_tokens, [:user_id])
    create index(:api_tokens, [:token_hash])
    create index(:api_tokens, [:expires_at])
  end
end
