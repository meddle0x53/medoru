defmodule Medoru.Repo.Migrations.AddOrderIndexToClassroomTests do
  use Ecto.Migration

  def up do
    alter table(:classroom_tests) do
      add :order_index, :integer, null: false, default: 0
    end

    create index(:classroom_tests, [:classroom_id, :order_index])
  end

  def down do
    drop index(:classroom_tests, [:classroom_id, :order_index])

    alter table(:classroom_tests) do
      remove :order_index
    end
  end
end
