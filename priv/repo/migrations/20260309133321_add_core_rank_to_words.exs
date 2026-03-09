defmodule Medoru.Repo.Migrations.AddCoreRankToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :core_rank, :integer, null: true
    end

    create index(:words, [:core_rank])
    create index(:words, [:difficulty, :core_rank])
  end
end
