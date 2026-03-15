defmodule Medoru.Repo.Migrations.MakeLessonIdNullableForCustomLessons do
  use Ecto.Migration

  def up do
    # Drop the existing foreign key constraint
    drop constraint(:classroom_lesson_progress, :classroom_lesson_progress_lesson_id_fkey)

    # Make lesson_id nullable to support custom lessons (which use custom_lesson_id instead)
    alter table(:classroom_lesson_progress) do
      modify :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: true
    end
  end

  def down do
    # Revert to non-nullable (will fail if any null lesson_id rows exist)
    alter table(:classroom_lesson_progress) do
      modify :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false
    end
  end
end
