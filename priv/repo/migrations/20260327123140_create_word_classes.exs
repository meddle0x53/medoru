defmodule Medoru.Repo.Migrations.CreateWordClasses do
  use Ecto.Migration

  def change do
    # Word classes (semantic categories like time, place, person, object)
    create table(:word_classes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :description, :text
      add :examples, {:array, :string}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:word_classes, [:name])

    # Join table: words <-> word_classes
    create table(:word_class_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all),
        null: false

      add :word_class_id,
          references(:word_classes, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:word_class_memberships, [:word_id, :word_class_id])
    create index(:word_class_memberships, [:word_class_id])
  end
end
