defmodule Medoru.Repo.Migrations.RenameRadicalHuntGamesRadicalToComponent do
  use Ecto.Migration

  def up do
    rename table(:radical_hunt_games), :radical, to: :component
  end

  def down do
    rename table(:radical_hunt_games), :component, to: :radical
  end
end
