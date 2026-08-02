defmodule Medoru.Repo.Migrations.CreateWordBooks do
  use Ecto.Migration

  def up do
    # Word books table
    create table(:word_books, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false, size: 100
      add :description, :text
      add :cover_image, :string
      add :theme, :string
      add :card_shape, :string, null: false, default: "rectangle"
      add :cards_per_page, :integer, null: false, default: 4
      add :front_background, :string
      add :back_background, :string
      add :front_config, :map, null: false, default: %{}
      add :back_config, :map, null: false, default: %{}
      add :word_count, :integer, default: 0, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Word book words join table
    create table(:word_book_words, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_book_id, references(:word_books, type: :binary_id, on_delete: :delete_all),
        null: false

      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create index(:word_books, [:user_id])
    create index(:word_books, [:title])
    create index(:word_books, [:inserted_at])

    create index(:word_book_words, [:word_book_id])
    create index(:word_book_words, [:word_id])
    create unique_index(:word_book_words, [:word_book_id, :word_id])
  end

  def down do
    drop table(:word_book_words)
    drop table(:word_books)
  end
end
