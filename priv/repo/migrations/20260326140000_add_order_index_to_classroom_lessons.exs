defmodule Medoru.Repo.Migrations.AddOrderIndexToClassroomLessons do
  use Ecto.Migration

  def change do
    alter table(:classroom_custom_lessons) do
      add :order_index, :integer, null: false, default: 0
    end

    create index(:classroom_custom_lessons, [:classroom_id, :order_index])
    create index(:classroom_custom_lessons, [:status])
  end
end
