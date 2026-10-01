defmodule Medoru.Repo.Migrations.CreateWordBookShares do
  use Ecto.Migration

  def change do
    create table(:word_book_shares, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_book_id, references(:word_books, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:word_book_shares, [:word_book_id])
    create index(:word_book_shares, [:sender_id])
    create index(:word_book_shares, [:recipient_id])

    create unique_index(:word_book_shares, [:word_book_id, :sender_id, :recipient_id],
             where: "status = 'pending'",
             name: :word_book_shares_pending_unique_index
           )
  end
end
