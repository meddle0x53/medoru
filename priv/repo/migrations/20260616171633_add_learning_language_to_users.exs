defmodule Medoru.Repo.Migrations.AddLearningLanguageToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :learning_language, :string, default: "japanese", null: false
    end
  end
end
