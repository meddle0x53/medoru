defmodule Medoru.Repo.Migrations.AddPushNotificationsToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :push_notifications_enabled, :boolean, default: false, null: false
    end
  end
end
