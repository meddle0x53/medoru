defmodule Medoru.Repo.Migrations.AddModeratorToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :moderator, :boolean, default: false, null: false
    end

    create index(:users, [:moderator])
  end
end
