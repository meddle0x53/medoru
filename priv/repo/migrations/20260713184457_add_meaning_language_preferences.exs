defmodule Medoru.Repo.Migrations.AddMeaningLanguagePreferences do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :show_japanese_meanings, :boolean, default: false, null: false
      add :show_bulgarian_meanings, :boolean, default: false, null: false
      add :show_english_meanings, :boolean, default: false, null: false
    end
  end
end
