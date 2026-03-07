defmodule Medoru.Repo.Migrations.AddBioToUserProfiles do
  use Ecto.Migration

  def up do
    alter table(:user_profiles) do
      add :bio, :text
    end

    # Add unique index on display_name (but allow NULLs)
    execute "CREATE UNIQUE INDEX user_profiles_display_name_index ON user_profiles (display_name) WHERE display_name IS NOT NULL"
  end

  def down do
    drop index(:user_profiles, [:display_name], name: "user_profiles_display_name_index")

    alter table(:user_profiles) do
      remove :bio
    end
  end
end
