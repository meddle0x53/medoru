defmodule Medoru.Repo.Migrations.CreateDictionaryEntries do
  use Ecto.Migration

  def change do
    create table(:dictionary_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :dictionary_id,
          references(:chat_dictionaries, type: :binary_id, on_delete: :delete_all), null: false

      add :key, :text, null: false
      add :value, :text, null: false
      add :category, :string
      add :match_mode, :string, default: "prefix", null: false

      timestamps(type: :utc_datetime)
    end

    create index(:dictionary_entries, [:dictionary_id])
    create index(:dictionary_entries, [:dictionary_id, "lower(category)"])
    create index(:dictionary_entries, ["lower(key)"])
  end
end
