defmodule Medoru.Repo.Migrations.AddThemeToClassrooms do
  use Ecto.Migration

  def change do
    alter table(:classrooms) do
      add :theme, :string
    end
  end
end
