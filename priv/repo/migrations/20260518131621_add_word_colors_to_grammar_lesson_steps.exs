defmodule Medoru.Repo.Migrations.AddWordColorsToGrammarLessonSteps do
  use Ecto.Migration

  def change do
    alter table(:grammar_lesson_steps) do
      add :word_colors, {:array, :map}, default: []
    end
  end
end
