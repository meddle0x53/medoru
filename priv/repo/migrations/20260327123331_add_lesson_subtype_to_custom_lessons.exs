defmodule Medoru.Repo.Migrations.AddLessonSubtypeToCustomLessons do
  use Ecto.Migration

  def change do
    alter table(:custom_lessons) do
      add :lesson_subtype, :string, default: "vocabulary", null: false
    end

    create index(:custom_lessons, [:lesson_subtype])
  end
end
