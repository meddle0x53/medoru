defmodule Medoru.Repo.Migrations.CreateWords do
  use Ecto.Migration

  def change do
    create table(:words, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string, null: false
      add :meaning, :string, null: false
      add :reading, :string, null: false
      add :difficulty, :integer, null: false
      add :usage_frequency, :integer, default: 1000

      timestamps(type: :utc_datetime)
    end

    create index(:words, [:difficulty])
    create index(:words, [:usage_frequency])
    create unique_index(:words, [:text])
  end
end
