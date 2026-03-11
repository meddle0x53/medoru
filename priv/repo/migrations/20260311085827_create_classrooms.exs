defmodule Medoru.Repo.Migrations.CreateClassrooms do
  use Ecto.Migration

  def change do
    create table(:classrooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :invite_code, :string, null: false
      add :status, :string, default: "active", null: false
      add :settings, :map, default: %{}
      add :teacher_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:classrooms, [:slug])
    create unique_index(:classrooms, [:invite_code])
    create index(:classrooms, [:teacher_id])
    create index(:classrooms, [:status])
  end
end
