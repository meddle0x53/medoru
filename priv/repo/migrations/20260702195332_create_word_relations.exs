defmodule Medoru.Repo.Migrations.CreateWordRelations do
  use Ecto.Migration

  def change do
    create table(:word_relations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :word_id, references(:words, type: :binary_id, on_delete: :delete_all), null: false
      add :related_word_id, references(:words, type: :binary_id, on_delete: :delete_all)
      add :relation_type, :string, null: false
      add :expression_text, :string
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:word_relations, [:word_id])
    create index(:word_relations, [:related_word_id])
    create index(:word_relations, [:word_id, :relation_type])

    create unique_index(
             :word_relations,
             [:word_id, :related_word_id, :relation_type, :expression_text],
             name: :word_relations_unique_entry,
             where: "status = 'approved'"
           )
  end
end
