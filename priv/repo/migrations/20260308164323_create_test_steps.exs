defmodule Medoru.Repo.Migrations.CreateTestSteps do
  use Ecto.Migration

  def change do
    create table(:test_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_index, :integer, null: false
      add :step_type, :string, null: false
      add :question_type, :string, null: false
      add :question, :text, null: false
      add :question_data, :map, null: false, default: %{}
      add :correct_answer, :string, null: false
      add :options, {:array, :string}, null: false, default: []
      add :points, :integer, null: false, default: 1
      add :hints, {:array, :string}, null: false, default: []
      add :explanation, :text
      add :time_limit_seconds, :integer

      add :test_id, references(:tests, type: :binary_id, on_delete: :delete_all), null: false
      add :kanji_id, references(:kanji, type: :binary_id, on_delete: :nilify_all)
      add :word_id, references(:words, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:test_steps, [:test_id])
    create index(:test_steps, [:kanji_id])
    create index(:test_steps, [:word_id])
    create index(:test_steps, [:step_type])
    create index(:test_steps, [:question_type])
    create unique_index(:test_steps, [:test_id, :order_index])
  end
end
