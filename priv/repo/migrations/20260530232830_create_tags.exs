defmodule Medoru.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :category, :string, null: false
      add :color, :string, default: "blue"
      add :description, :text
      add :order_index, :integer, default: 0
      add :is_official, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:slug])
    create unique_index(:tags, [:name])
    create index(:tags, [:category])
    create index(:tags, [:order_index])
  end
end
