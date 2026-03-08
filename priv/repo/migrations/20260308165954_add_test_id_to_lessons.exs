defmodule Medoru.Repo.Migrations.AddTestIdToLessons do
  use Ecto.Migration

  def change do
    alter table(:lessons) do
      add :test_id, references(:tests, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:lessons, [:test_id])
  end
end
