defmodule Medoru.Repo.Migrations.AddStepsPerWordToCustomLessons do
  use Ecto.Migration

  def up do
    alter table(:custom_lessons) do
      add :steps_per_word, :integer, default: 3, null: false
    end

    # Update existing lessons to use 3 steps per word (current behavior)
    execute "UPDATE custom_lessons SET steps_per_word = 3"
  end

  def down do
    alter table(:custom_lessons) do
      remove :steps_per_word
    end
  end
end
