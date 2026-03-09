defmodule Medoru.Repo.Migrations.AddSortScoreToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :sort_score, :integer, null: true
    end

    # Index for fast sorting during lesson generation
    create index(:words, [:difficulty, :sort_score])
  end
end
