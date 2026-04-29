defmodule Medoru.Repo.Migrations.AddPronunciationToWords do
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :pronunciation_path, :string
    end
  end
end
