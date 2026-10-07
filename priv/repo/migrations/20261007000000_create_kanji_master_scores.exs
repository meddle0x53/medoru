defmodule Medoru.Repo.Migrations.CreateKanjiMasterScores do
  use Ecto.Migration

  def up do
    create table(:kanji_master_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :score, :integer, null: false, default: 0

      add :display_mode, :string,
        null: false,
        default: "linked",
        comment: "linked | anonymous"

      add :anonymous_name, :string

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:kanji_master_scores, [:user_id])
    create index(:kanji_master_scores, [:score])
  end

  def down do
    drop table(:kanji_master_scores)
  end
end
