defmodule Medoru.Repo.Migrations.AddIsDeletedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_deleted, :boolean, default: false, null: false
    end

    create index(:users, [:is_deleted])
  end
end
