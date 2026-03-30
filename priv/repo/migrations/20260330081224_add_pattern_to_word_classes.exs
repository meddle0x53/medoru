defmodule Medoru.Repo.Migrations.AddPatternToWordClasses do
  use Ecto.Migration

  def change do
    alter table(:word_classes) do
      add :pattern, :text
    end

    # Add index for quick lookup
    create index(:word_classes, [:pattern])
  end
end
