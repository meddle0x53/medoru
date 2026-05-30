defmodule Medoru.Social.Tag do
  @moduledoc """
  Schema for user tags (curated official tags that users can display on their profiles).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    field :name, :string
    field :slug, :string
    field :category, :string
    field :color, :string, default: "blue"
    field :description, :string
    field :order_index, :integer, default: 0
    field :is_official, :boolean, default: true

    has_many :user_tags, Medoru.Social.UserTag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug, :category, :color, :description, :order_index, :is_official])
    |> validate_required([:name, :slug, :category])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:slug, min: 1, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
        message: "can only contain lowercase letters, numbers, and hyphens")
    |> validate_inclusion(:category, ["level", "music", "movies", "literature", "gaming", "lifestyle", "sport", "goal"])
    |> unique_constraint(:slug)
    |> unique_constraint(:name)
  end
end
