defmodule Medoru.Repo.Migrations.CreateClassroomMemberships do
  use Ecto.Migration

  def change do
    create table(:classroom_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "pending", null: false
      add :role, :string, default: "student", null: false
      add :joined_at, :utc_datetime
      add :points, :integer, default: 0, null: false
      add :settings, :map, default: %{}

      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:classroom_memberships, [:classroom_id, :user_id])
    create index(:classroom_memberships, [:classroom_id])
    create index(:classroom_memberships, [:user_id])
    create index(:classroom_memberships, [:status])
  end
end
