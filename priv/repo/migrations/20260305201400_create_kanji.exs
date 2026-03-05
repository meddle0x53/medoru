defmodule Medoru.Repo.Migrations.CreateKanji do
  use Ecto.Migration

  def change do
    create table(:kanji, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character, :string, null: false
      add :meanings, {:array, :string}, null: false
      add :stroke_count, :integer, null: false
      add :jlpt_level, :integer, null: false
      add :stroke_data, :map, default: %{}
      add :radicals, {:array, :string}, default: []
      add :frequency, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:kanji, [:character])
    create index(:kanji, [:jlpt_level])
    create index(:kanji, [:frequency])
  end
end
