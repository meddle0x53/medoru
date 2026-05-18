defmodule Medoru.Repo.Migrations.AddWordColorsToCustomLessons do
  use Ecto.Migration

  def change do
    alter table(:custom_lessons) do
      add :word_colors, {:array, :map}, default: []
    end
  end
end
