defmodule Medoru.Repo.Migrations.AddNotificationPreferencesToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :notify_messaging, :boolean, default: true, null: false
      add :notify_white_board, :boolean, default: true, null: false
      add :notify_achievements, :boolean, default: true, null: false
    end
  end
end
