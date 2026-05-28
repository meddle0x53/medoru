defmodule Medoru.Repo.Migrations.AddNotificationsIndex do
  use Ecto.Migration

  def change do
    # Composite index for efficient paginated notification queries per user
    create index(:notifications, [:user_id, :inserted_at])
  end
end
