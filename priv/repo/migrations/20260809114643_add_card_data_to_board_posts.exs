defmodule Medoru.Repo.Migrations.AddCardDataToBoardPosts do
  use Ecto.Migration

  def up do
    alter table(:board_posts) do
      add :card_data, :map
    end
  end

  def down do
    alter table(:board_posts) do
      remove :card_data
    end
  end
end
