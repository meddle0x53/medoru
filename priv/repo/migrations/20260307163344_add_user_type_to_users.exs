defmodule Medoru.Repo.Migrations.AddUserTypeToUsers do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE user_type AS ENUM ('student', 'teacher', 'admin')"

    alter table(:users) do
      add :type, :user_type, null: false, default: "student"
    end

    create index(:users, [:type])
  end

  def down do
    drop index(:users, [:type])

    alter table(:users) do
      remove :type
    end

    execute "DROP TYPE user_type"
  end
end
