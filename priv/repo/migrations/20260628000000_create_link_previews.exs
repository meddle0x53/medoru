defmodule Medoru.Repo.Migrations.CreateLinkPreviews do
  use Ecto.Migration

  def change do
    create table(:link_previews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :url, :text, null: false
      add :title, :string
      add :description, :text
      add :image_url, :text
      add :site_name, :string
      add :favicon_url, :text
      add :status, :string, null: false, default: "pending"
      add :error_message, :string
      add :fetched_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:link_previews, [:url])
    create index(:link_previews, [:status, :inserted_at])
  end
end
