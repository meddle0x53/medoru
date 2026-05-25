defmodule Medoru.Repo.Migrations.AddMessageAttachments do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :attachment_path, :string
      add :attachment_type, :string
      add :duration_seconds, :integer
    end

    create index(:messages, [:attachment_type])
  end
end
