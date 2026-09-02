defmodule Medoru.Repo.Migrations.DictionaryEntriesUsecTimestamps do
  use Ecto.Migration

  def up do
    alter table(:dictionary_entries) do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    # supports the paginated/sorted dictionary queries per dictionary
    create index(:dictionary_entries, [:dictionary_id, "lower(key)"])
  end

  def down do
    drop index(:dictionary_entries, [:dictionary_id, "lower(key)"])

    alter table(:dictionary_entries) do
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end
  end
end
