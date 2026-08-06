defmodule Medoru.Repo.Migrations.AddCustomTextToWordBooks do
  use Ecto.Migration

  def up do
    alter table(:word_books) do
      add :custom_text, :string
    end
  end

  def down do
    alter table(:word_books) do
      remove :custom_text
    end
  end
end
