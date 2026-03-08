defmodule Medoru.Repo.Migrations.CreateTests do
  use Ecto.Migration

  def change do
    create table(:tests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :test_type, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :total_points, :integer, null: false, default: 0
      add :time_limit_seconds, :integer
      add :is_system, :boolean, null: false, default: false
      add :metadata, :map, null: false, default: %{}

      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :nilify_all)
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tests, [:test_type])
    create index(:tests, [:status])
    create index(:tests, [:is_system])
    create index(:tests, [:lesson_id])
    create index(:tests, [:creator_id])
    create index(:tests, [:inserted_at])
  end
end
