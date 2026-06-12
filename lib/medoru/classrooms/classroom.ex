defmodule Medoru.Classrooms.Classroom do
  @moduledoc """
  Schema for classrooms.

  Classrooms are created by teachers and can have multiple student members.
  Each classroom has a unique slug and invite code for students to join.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "classrooms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :invite_code, :string
    field :status, Ecto.Enum, values: [:active, :archived, :closed], default: :active
    field :should_approve_memberships, :boolean, default: true
    field :public, :boolean, default: false
    field :theme, :string
    field :settings, :map, default: %{}

    belongs_to :teacher, Medoru.Accounts.User
    has_many :memberships, Medoru.Classrooms.ClassroomMembership
    has_many :students, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  @allowed_themes [
    "light",
    "dark",
    "cupcake",
    "bumblebee",
    "emerald",
    "corporate",
    "synthwave",
    "retro",
    "cyberpunk",
    "valentine",
    "halloween",
    "garden",
    "forest",
    "aqua",
    "lofi",
    "pastel",
    "fantasy",
    "wireframe",
    "black",
    "luxury",
    "dracula",
    "cmyk",
    "autumn",
    "business",
    "acid",
    "lemonade",
    "night",
    "coffee",
    "winter",
    "dim",
    "nord",
    "sunset"
  ]

  def allowed_themes, do: @allowed_themes

  @doc false
  def changeset(classroom, attrs) do
    classroom
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :invite_code,
      :status,
      :should_approve_memberships,
      :public,
      :theme,
      :settings,
      :teacher_id
    ])
    |> validate_required([:name, :invite_code, :teacher_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_theme()
    |> validate_slug()
    |> unique_constraint(:slug)
    |> unique_constraint(:invite_code)
    |> foreign_key_constraint(:teacher_id)
  end

  defp validate_theme(changeset) do
    theme = get_field(changeset, :theme)

    if is_nil(theme) or theme == "" or theme in @allowed_themes do
      changeset
    else
      add_error(changeset, :theme, "is not a valid theme")
    end
  end

  # Validates slug only if one is provided (slug is auto-generated if empty)
  defp validate_slug(changeset) do
    slug = get_field(changeset, :slug)

    if slug && slug != "" do
      changeset
      |> validate_length(:slug, min: 3, max: 50)
      |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
        message: "can only contain lowercase letters, numbers, and hyphens"
      )
    else
      changeset
    end
  end

  @doc """
  Generates a random invite code.
  """
  def generate_invite_code do
    :crypto.strong_rand_bytes(6)
    |> Base.encode32(case: :lower)
    |> binary_part(0, 8)
    |> String.upcase()
  end

  @doc """
  Generates a slug from a classroom name.
  """
  def generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 50)
  end
end
