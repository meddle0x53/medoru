defmodule Medoru.Repo.Migrations.AddClassroomIdToConversations do
  use Ecto.Migration

  def up do
    alter table(:conversations) do
      add :classroom_id, references(:classrooms, type: :binary_id, on_delete: :nilify_all)
    end

    create unique_index(:conversations, [:classroom_id])
  end

  def down do
    drop index(:conversations, [:classroom_id])

    alter table(:conversations) do
      remove :classroom_id
    end
  end
end
