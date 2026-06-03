defmodule Medoru.Repo.Migrations.AddKnownScoreToUserProgress do
  use Ecto.Migration

  def up do
    alter table(:user_progress) do
      add :known_score, :integer, null: false, default: 0
    end

    create index(:user_progress, [:user_id, :known_score])

    # Backfill existing kanji progress records
    execute("""
    UPDATE user_progress
    SET known_score = 1
    WHERE kanji_id IS NOT NULL AND mastery_level >= 1
    """)
  end

  def down do
    drop index(:user_progress, [:user_id, :known_score])

    alter table(:user_progress) do
      remove :known_score
    end
  end
end
