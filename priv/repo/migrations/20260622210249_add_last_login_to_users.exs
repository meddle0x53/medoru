defmodule Medoru.Repo.Migrations.AddLastLoginToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_login, :utc_datetime
    end

    create index(:users, [:last_login])
  end
end
