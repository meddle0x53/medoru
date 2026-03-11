defmodule Medoru.Repo.Migrations.AddSetupStateToTests do
  use Ecto.Migration

  def change do
    # Add setup_state field for teacher test lifecycle
    alter table(:tests) do
      add :setup_state, :string, null: false, default: "in_progress"
      add :max_attempts, :integer
    end

    # Index for filtering teacher tests by setup_state
    create index(:tests, [:creator_id, :setup_state])
    create index(:tests, [:setup_state])
  end
end
