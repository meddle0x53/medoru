defmodule Medoru.Repo.Migrations.AddShowPicturesAndShowSoundsToCustomLessons do
  use Ecto.Migration

  def up do
    alter table(:custom_lessons) do
      add :show_pictures, :boolean, default: true, null: false
      add :show_sounds, :boolean, default: true, null: false
    end
  end

  def down do
    alter table(:custom_lessons) do
      remove :show_pictures
      remove :show_sounds
    end
  end
end
