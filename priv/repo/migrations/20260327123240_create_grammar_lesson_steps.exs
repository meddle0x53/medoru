defmodule Medoru.Repo.Migrations.CreateGrammarLessonSteps do
  use Ecto.Migration

  def change do
    create table(:grammar_lesson_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :position, :integer, null: false
      add :title, :string
      add :explanation, :text
      add :examples, {:array, :map}, default: []
      add :pattern_elements, {:array, :map}, default: []
      add :difficulty, :integer

      add :custom_lesson_id,
          references(:custom_lessons, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:grammar_lesson_steps, [:custom_lesson_id])
    create index(:grammar_lesson_steps, [:custom_lesson_id, :position])
  end
end
