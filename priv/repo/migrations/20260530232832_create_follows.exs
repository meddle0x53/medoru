defmodule Medoru.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :follower_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :following_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :followed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:follows, [:follower_id, :following_id])
    create index(:follows, [:following_id])

    create constraint(:follows, :cannot_follow_self,
      check: "follower_id != following_id"
    )
  end
end
