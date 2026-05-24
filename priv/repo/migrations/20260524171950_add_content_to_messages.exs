defmodule Medoru.Repo.Migrations.AddContentToMessages do
  use Ecto.Migration

  def up do
    alter table(:messages) do
      add :content, :text
    end
  end

  def down do
    alter table(:messages) do
      remove :content
    end
  end
end
