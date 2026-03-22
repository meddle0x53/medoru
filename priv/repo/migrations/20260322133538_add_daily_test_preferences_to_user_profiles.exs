defmodule Medoru.Repo.Migrations.AddDailyTestPreferencesToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      # Array of selected step types for daily tests
      # Available: :word_to_meaning, :word_to_reading, :reading_text
      add :daily_test_step_types, {:array, :string}, default: ["word_to_meaning", "word_to_reading", "reading_text"]
    end
  end
end
