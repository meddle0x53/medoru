defmodule Medoru.Repo.Migrations.CreateXpTransactions do
  use Ecto.Migration

  def change do
    create table(:xp_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :integer, null: false
      add :source_type, :string, null: false
      add :source_id, :string
      add :description, :string
      add :awarded_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:xp_transactions, [:user_id])
    create index(:xp_transactions, [:user_id, :source_type])
    create index(:xp_transactions, [:awarded_at])
  end
end
