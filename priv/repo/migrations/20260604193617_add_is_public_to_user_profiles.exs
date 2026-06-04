defmodule Medoru.Repo.Migrations.AddIsPublicToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :is_public, :boolean, default: true, null: false
    end
  end
end
