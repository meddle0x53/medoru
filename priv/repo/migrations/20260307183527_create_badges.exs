defmodule Medoru.Repo.Migrations.CreateBadges do
  use Ecto.Migration

  def change do
    create table(:badges) do
      add :name, :string, null: false
      add :description, :text, null: false
      add :icon, :string, null: false
      add :color, :string, null: false, default: "blue"
      add :criteria_type, :string, null: false, default: "manual"
      add :criteria_value, :integer
      add :order_index, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:badges, [:name])
    create index(:badges, [:criteria_type])
    create index(:badges, [:order_index])
  end
end
