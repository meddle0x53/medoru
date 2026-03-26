defmodule Medoru.Repo.Migrations.AddSchoolLevelToKanji do
  use Ecto.Migration

  def change do
    alter table(:kanji) do
      # Japanese school grade levels (SL1-SL7)
      # 1-6 = Elementary school grades (Kyouiku kanji)
      # 7 = Junior high school (remaining Jouyou kanji)
      # nil = Not part of standard school curriculum
      add :school_level, :integer
    end

    create index(:kanji, [:school_level])
  end
end
