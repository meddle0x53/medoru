defmodule Medoru.Repo.Migrations.MakeTestSessionsUserIdNullable do
  use Ecto.Migration

  def change do
    alter table(:test_sessions) do
      modify :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: true,
        from: references(:users, type: :binary_id, on_delete: :delete_all)
    end
  end
end
