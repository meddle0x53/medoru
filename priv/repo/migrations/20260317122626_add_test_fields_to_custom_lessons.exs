defmodule Medoru.Repo.Migrations.AddTestFieldsToCustomLessons do
  use Ecto.Migration

  def change do
    alter table(:custom_lessons) do
      add :requires_test, :boolean, default: false, null: false
      add :include_writing, :boolean, default: false, null: false
      add :test_id, references(:tests, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:custom_lessons, [:test_id])
  end
end
