defmodule Medoru.Repo.Migrations.AddLocaleToUserProfiles do
  use Ecto.Migration

  def up, do: alter(table(:user_profiles), do: add(:locale, :string, default: "en", null: false))
  def down, do: alter(table(:user_profiles), do: remove(:locale))
end
