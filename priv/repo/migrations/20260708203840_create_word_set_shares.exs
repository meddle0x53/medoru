defmodule Medoru.Repo.Migrations.CreateWordSetShares do
  use Ecto.Migration

  def change do
    create table(:word_set_shares, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_set_id, references(:word_sets, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:word_set_shares, [:word_set_id])
    create index(:word_set_shares, [:sender_id])
    create index(:word_set_shares, [:recipient_id])

    create unique_index(:word_set_shares, [:word_set_id, :sender_id, :recipient_id],
             where: "status = 'pending'",
             name: :word_set_shares_pending_unique_index
           )
  end
end
