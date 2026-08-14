defmodule Medoru.Repo.Migrations.CreateProfileVisits do
  use Ecto.Migration

  def up do
    create table(:profile_visits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :visitor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :visited_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :visited_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profile_visits, [:visitor_id, :visited_user_id])
    create index(:profile_visits, [:visited_user_id])
    create index(:profile_visits, [:visited_at])

    create constraint(:profile_visits, :cannot_visit_self, check: "visitor_id != visited_user_id")
  end

  def down do
    drop table(:profile_visits)
  end
end
