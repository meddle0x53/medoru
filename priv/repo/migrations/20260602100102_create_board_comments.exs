defmodule Medoru.Repo.Migrations.CreateBoardComments do
  use Ecto.Migration

  def change do
    create table(:board_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:board_posts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:board_comments, type: :binary_id, on_delete: :delete_all)
      add :content, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:board_comments, [:post_id, :inserted_at])
    create index(:board_comments, [:parent_id])
  end
end
