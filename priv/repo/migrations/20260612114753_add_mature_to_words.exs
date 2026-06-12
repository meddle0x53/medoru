defmodule Medoru.Repo.Migrations.AddMatureToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :mature, :boolean, default: false, null: false
    end
  end
end
