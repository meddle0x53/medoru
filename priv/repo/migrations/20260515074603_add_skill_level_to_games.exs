defmodule Medoru.Repo.Migrations.AddSkillLevelToGames do
  use Ecto.Migration

  def up do
    alter table(:games) do
      add :skill_level, :integer, default: 1, null: false
    end

    create index(:games, [:skill_level])
  end

  def down do
    drop index(:games, [:skill_level])

    alter table(:games) do
      remove :skill_level
    end
  end
end
