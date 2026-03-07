defmodule Medoru.Repo.Migrations.AddFeaturedBadgeToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :featured_badge_id, references(:badges, on_delete: :nilify_all)
    end

    create index(:user_profiles, [:featured_badge_id])
  end
end
