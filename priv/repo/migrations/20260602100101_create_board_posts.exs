defmodule Medoru.Repo.Migrations.CreateBoardPosts do
  use Ecto.Migration

  def change do
    create table(:board_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string
      add :content, :text
      add :visibility, :string, null: false, default: "public"
      add :post_type, :string, null: false, default: "text"
      add :canvas_data, :map
      timestamps(type: :utc_datetime)
    end

    create index(:board_posts, [:user_id, :inserted_at])
    create index(:board_posts, [:visibility])
  end
end
