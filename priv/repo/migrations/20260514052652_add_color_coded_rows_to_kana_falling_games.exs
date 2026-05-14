defmodule Medoru.Repo.Migrations.AddColorCodedRowsToKanaFallingGames do
  use Ecto.Migration

  def change do
    alter table(:kana_falling_games) do
      add :color_coded_rows, :boolean, default: false, null: false
    end
  end
end
