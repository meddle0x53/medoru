defmodule Medoru.Repo.Migrations.AddThemeToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :theme, :string, null: true
    end
  end
end
