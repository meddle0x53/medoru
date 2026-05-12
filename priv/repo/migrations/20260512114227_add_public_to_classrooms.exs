defmodule Medoru.Repo.Migrations.AddPublicToClassrooms do
  use Ecto.Migration

  def change do
    alter table(:classrooms) do
      add :public, :boolean, null: false, default: false
    end

    create index(:classrooms, [:public])
  end
end
