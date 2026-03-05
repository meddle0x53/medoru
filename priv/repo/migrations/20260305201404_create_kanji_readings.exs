defmodule Medoru.Repo.Migrations.CreateKanjiReadings do
  use Ecto.Migration

  def change do
    create table(:kanji_readings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reading_type, :string, null: false
      add :reading, :string, null: false
      add :romaji, :string, null: false
      add :usage_notes, :text
      add :kanji_id, references(:kanji, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:kanji_readings, [:kanji_id])
    create index(:kanji_readings, [:reading_type])
  end
end
