defmodule Medoru.Repo.Migrations.CreateWordKanjis do
  use Ecto.Migration

  def change do
    create table(:word_kanjis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false
      add :kanji_id, references(:kanji, type: :binary_id, on_delete: :delete_all), null: false
      add :kanji_reading_id, references(:kanji_readings, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:word_kanjis, [:word_id])
    create index(:word_kanjis, [:kanji_id])
    create index(:word_kanjis, [:kanji_reading_id])
    create unique_index(:word_kanjis, [:word_id, :kanji_id, :position])
  end
end
