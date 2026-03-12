defmodule Medoru.Repo.Migrations.AddKanjiIdToTestSteps do
  use Ecto.Migration

  def up do
    # Check if column exists first
    unless column_exists?(:test_steps, :kanji_id) do
      alter table(:test_steps) do
        add :kanji_id, references(:kanji, type: :binary_id, on_delete: :nilify_all)
      end

      create index(:test_steps, [:kanji_id])
    end
  end

  def down do
    if column_exists?(:test_steps, :kanji_id) do
      drop index(:test_steps, [:kanji_id])

      alter table(:test_steps) do
        remove :kanji_id
      end
    end
  end

  defp column_exists?(table, column) do
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_name = '#{table}'
      AND column_name = '#{column}'
    );
    """

    case repo().query(query) do
      {:ok, %{rows: [[exists]]}} -> exists
      _ -> false
    end
  end
end
