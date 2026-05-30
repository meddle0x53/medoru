defmodule Medoru.Repo.Migrations.AddProfileFieldsToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :age, :integer
      add :gender, :integer
      add :location, :string
    end
  end
end
