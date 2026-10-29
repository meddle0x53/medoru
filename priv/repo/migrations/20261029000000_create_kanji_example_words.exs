defmodule Medoru.Repo.Migrations.CreateKanjiExampleWords do
  use Ecto.Migration

  def up do
    create table(:kanji_example_words, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, default: 0, null: false
      add :kanji_id, references(:kanji, type: :binary_id, on_delete: :delete_all), null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kanji_example_words, [:kanji_id, :word_id])
    create index(:kanji_example_words, [:kanji_id])
  end

  def down do
    drop table(:kanji_example_words)
  end
end
