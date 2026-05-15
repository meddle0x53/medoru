defmodule Medoru.Repo.Migrations.CreateSiteSettings do
  use Ecto.Migration

  def change do
    create table(:site_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :featured_classroom_id, references(:classrooms, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:site_settings, [:featured_classroom_id])
  end
end
