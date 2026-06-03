defmodule Medoru.Repo.Migrations.MakeKanjiJlptLevelNullable do
  use Ecto.Migration

  def up do
    alter table(:kanji) do
      modify :jlpt_level, :integer, null: true, from: {:integer, null: false}
    end
  end

  def down do
    alter table(:kanji) do
      modify :jlpt_level, :integer, null: false, from: {:integer, null: true}
    end
  end
end
