defmodule Medoru.Repo.Migrations.AddExampleSentencesToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :example_sentence, :text, null: true
      add :example_reading, :text, null: true
      add :example_meaning, :text, null: true
    end
  end
end
