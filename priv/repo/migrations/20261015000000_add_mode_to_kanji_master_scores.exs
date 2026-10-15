defmodule Medoru.Repo.Migrations.AddModeToKanjiMasterScores do
  use Ecto.Migration

  def up do
    alter table(:kanji_master_scores) do
      add :mode, :string, null: false, default: "master"
      # Anonymous N5 entries have no user.
      modify :user_id, :binary_id, null: true
    end

    # One row per user per mode. A plain unique index on user_id would
    # prevent one user from ranking in both modes. NULL user_ids are
    # distinct under a unique index, so anonymous upserts key on
    # (mode, anonymous_name) in the context instead.
    drop unique_index(:kanji_master_scores, [:user_id])
    create unique_index(:kanji_master_scores, [:user_id, :mode])
    create index(:kanji_master_scores, [:mode])
  end

  def down do
    # Anonymous rows can't satisfy the restored NOT NULL constraint.
    execute "DELETE FROM kanji_master_scores WHERE user_id IS NULL"

    drop index(:kanji_master_scores, [:mode])
    drop unique_index(:kanji_master_scores, [:user_id, :mode])

    alter table(:kanji_master_scores) do
      remove :mode
      modify :user_id, :binary_id, null: false
    end

    create unique_index(:kanji_master_scores, [:user_id])
  end
end
