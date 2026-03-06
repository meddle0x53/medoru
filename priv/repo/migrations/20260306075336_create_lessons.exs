defmodule Medoru.Repo.Migrations.CreateLessons do
  use Ecto.Migration

  def change do
    create table(:lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :difficulty, :integer, null: false
      add :order_index, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lessons, [:difficulty])
    create index(:lessons, [:order_index])
    create unique_index(:lessons, [:difficulty, :order_index])
  end
end
