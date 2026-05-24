defmodule Medoru.Repo.Migrations.AddIndexOnDisplayName do
  use Ecto.Migration

  def up do
    execute "CREATE INDEX IF NOT EXISTS user_profiles_display_name_index ON user_profiles (display_name)"
  end

  def down do
    execute "DROP INDEX IF EXISTS user_profiles_display_name_index"
  end
end
