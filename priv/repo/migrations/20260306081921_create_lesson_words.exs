defmodule Medoru.Repo.Migrations.CreateLessonWords do
  use Ecto.Migration

  def change do
    create table(:lesson_words, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lesson_words, [:lesson_id])
    create index(:lesson_words, [:word_id])
    create unique_index(:lesson_words, [:lesson_id, :position])
    create unique_index(:lesson_words, [:lesson_id, :word_id])
  end
end
