defmodule Medoru.Repo.Migrations.AddSafetyToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :safety, :boolean, default: true, null: false
    end
  end
end
