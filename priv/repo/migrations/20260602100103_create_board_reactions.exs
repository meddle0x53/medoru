defmodule Medoru.Repo.Migrations.CreateBoardReactions do
  use Ecto.Migration

  def change do
    create table(:board_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:board_posts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :emoji, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:board_reactions, [:post_id, :user_id, :emoji])
  end
end
