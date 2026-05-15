defmodule Medoru.Repo.Migrations.BackfillCustomLessonDifficulty do
  use Ecto.Migration

  def up do
    execute "UPDATE custom_lessons SET difficulty = 1 WHERE difficulty IS NULL"
  end

  def down do
    # No-op: we can't know which rows previously had NULL
  end
end
