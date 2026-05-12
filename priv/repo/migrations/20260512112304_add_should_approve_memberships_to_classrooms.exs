defmodule Medoru.Repo.Migrations.AddShouldApproveMembershipsToClassrooms do
  use Ecto.Migration

  def change do
    alter table(:classrooms) do
      add :should_approve_memberships, :boolean, null: false, default: true
    end
  end
end
