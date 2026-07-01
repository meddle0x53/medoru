defmodule Medoru.Repo.Migrations.AddPositionToKanjiReadings do
  use Ecto.Migration

  def change do
    alter table(:kanji_readings) do
      add :position, :integer, null: false, default: 0
    end
  end
end
