defmodule Medoru.Repo.Migrations.CreateCustomLessons do
  use Ecto.Migration

  def change do
    # Custom lessons created by teachers
    create table(:custom_lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :lesson_type, :string, default: "reading", null: false
      add :difficulty, :integer
      add :status, :string, default: "draft", null: false
      add :word_count, :integer, default: 0, null: false
      add :creator_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:custom_lessons, [:creator_id])
    create index(:custom_lessons, [:status])
    create index(:custom_lessons, [:creator_id, :status])

    # Words in custom lessons with custom meanings and examples
    create table(:custom_lesson_words, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :custom_meaning, :text
      add :examples, {:array, :text}, default: [], null: false
      add :custom_lesson_id, references(:custom_lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:custom_lesson_words, [:custom_lesson_id])
    create index(:custom_lesson_words, [:custom_lesson_id, :position])
    create unique_index(:custom_lesson_words, [:custom_lesson_id, :word_id])

    # Publishing custom lessons to classrooms
    create table(:classroom_custom_lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "active", null: false
      add :due_date, :date
      add :points_override, :integer
      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all), null: false
      add :custom_lesson_id, references(:custom_lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :published_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :published_at, :utc_datetime_usec
      add :unpublished_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:classroom_custom_lessons, [:classroom_id])
    create index(:classroom_custom_lessons, [:custom_lesson_id])
    create index(:classroom_custom_lessons, [:classroom_id, :status])
    create unique_index(:classroom_custom_lessons, [:classroom_id, :custom_lesson_id], name: :classroom_custom_lessons_unique_lesson)

    # Extend classroom_lesson_progress for custom lessons
    alter table(:classroom_lesson_progress) do
      add :lesson_source, :string, default: "system", null: false
      add :custom_lesson_id, references(:custom_lessons, type: :binary_id, on_delete: :delete_all)
    end

    create index(:classroom_lesson_progress, [:custom_lesson_id])
    create index(:classroom_lesson_progress, [:classroom_id, :user_id, :lesson_source])
  end
end
