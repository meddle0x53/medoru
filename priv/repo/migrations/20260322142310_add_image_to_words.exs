defmodule Medoru.Repo.Migrations.AddImageToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :image_path, :string
    end
  end
end
