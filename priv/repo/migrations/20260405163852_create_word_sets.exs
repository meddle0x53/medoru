defmodule Medoru.Repo.Migrations.CreateWordSets do
  use Ecto.Migration

  def up do
    # Word sets table
    create table(:word_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false, size: 100
      add :description, :text
      add :word_count, :integer, default: 0, null: false
      add :practice_test_id, references(:tests, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    # Word set words join table
    create table(:word_set_words, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_set_id, references(:word_sets, type: :binary_id, on_delete: :delete_all),
        null: false

      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create index(:word_sets, [:user_id])
    create index(:word_sets, [:practice_test_id])
    create index(:word_sets, [:name])
    create index(:word_sets, [:inserted_at])

    create index(:word_set_words, [:word_set_id])
    create index(:word_set_words, [:word_id])
    create unique_index(:word_set_words, [:word_set_id, :word_id])
  end

  def down do
    drop table(:word_set_words)
    drop table(:word_sets)
  end
end
