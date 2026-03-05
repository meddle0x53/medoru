defmodule Medoru.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :display_name, :string
      add :avatar, :string
      add :timezone, :string, default: "UTC", null: false
      add :daily_goal, :integer, default: 10, null: false
      add :theme, :string, default: "light", null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_profiles, [:user_id])
  end
end
