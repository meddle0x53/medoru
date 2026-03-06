defmodule Medoru.Repo.Migrations.CreateLessonKanjis do
  use Ecto.Migration

  def change do
    create table(:lesson_kanjis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :kanji_id, references(:kanji, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lesson_kanjis, [:lesson_id])
    create index(:lesson_kanjis, [:kanji_id])
    create unique_index(:lesson_kanjis, [:lesson_id, :position])
    create unique_index(:lesson_kanjis, [:lesson_id, :kanji_id])
  end
end
