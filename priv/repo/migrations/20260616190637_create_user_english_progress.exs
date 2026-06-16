defmodule Medoru.Repo.Migrations.CreateUserEnglishProgress do
  use Ecto.Migration

  def change do
    create table(:user_english_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_english_progress, [:user_id])
    create index(:user_english_progress, [:word_id])

    create unique_index(:user_english_progress, [:user_id, :word_id],
             name: :user_english_progress_user_id_word_id_index
           )
  end
end
