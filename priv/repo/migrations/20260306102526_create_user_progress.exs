defmodule Medoru.Repo.Migrations.CreateUserProgress do
  use Ecto.Migration

  def change do
    create table(:user_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :mastery_level, :integer, null: false, default: 0
      add :times_reviewed, :integer, null: false, default: 0
      add :last_reviewed_at, :utc_datetime
      add :next_review_at, :utc_datetime

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :kanji_id, references(:kanji, type: :binary_id, on_delete: :delete_all)
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    # Indexes for common queries
    create index(:user_progress, [:user_id])
    create index(:user_progress, [:kanji_id])
    create index(:user_progress, [:word_id])
    create index(:user_progress, [:user_id, :mastery_level])
    create index(:user_progress, [:user_id, :next_review_at])

    # Unique constraints - user can only have one progress per kanji/word
    create unique_index(:user_progress, [:user_id, :kanji_id],
             where: "kanji_id IS NOT NULL",
             name: :user_progress_user_id_kanji_id_index
           )

    create unique_index(:user_progress, [:user_id, :word_id],
             where: "word_id IS NOT NULL",
             name: :user_progress_user_id_word_id_index
           )
  end
end
