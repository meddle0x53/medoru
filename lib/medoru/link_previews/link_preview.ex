defmodule Medoru.LinkPreviews.LinkPreview do
  @moduledoc """
  Schema for cached external link previews (Open Graph metadata).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "link_previews" do
    field :url, :string
    field :title, :string
    field :description, :string
    field :image_url, :string
    field :site_name, :string
    field :favicon_url, :string
    field :status, :string, default: "pending"
    field :error_message, :string
    field :fetched_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @statuses ["pending", "fetched", "failed", "blocked"]

  def changeset(link_preview, attrs) do
    link_preview
    |> cast(attrs, [
      :url,
      :title,
      :description,
      :image_url,
      :site_name,
      :favicon_url,
      :status,
      :error_message,
      :fetched_at
    ])
    |> validate_required([:url, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:url)
  end
end
