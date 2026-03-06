defmodule Medoru.Repo.Migrations.AddLessonType do
  use Ecto.Migration

  def up do
    # Create the enum type
    execute(
      "CREATE TYPE lesson_type AS ENUM ('reading', 'writing', 'listening', 'speaking', 'grammar')"
    )

    # Add the type column with default 'reading'
    alter table(:lessons) do
      add :lesson_type, :lesson_type, null: false, default: "reading"
    end

    # Create index for filtering by type
    create index(:lessons, [:lesson_type])
  end

  def down do
    alter table(:lessons) do
      remove :lesson_type
    end

    execute("DROP TYPE lesson_type")
  end
end
