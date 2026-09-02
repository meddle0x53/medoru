defmodule Medoru.Social.UserRelation do
  @moduledoc """
  Schema for a unilateral, private relation from one user to another.

  The owner user can record nicknames, a relationship type, a description,
  and the formality style they use when addressing the target user.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_relations" do
    field :relationship_type, :string
    field :description, :string
    field :address_style, :string
    field :nicknames, {:array, :string}, default: []

    belongs_to :user, Medoru.Accounts.User
    belongs_to :target_user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @relationship_types ~w(
    acquaintance
    friend
    close-friend
    father
    mother
    sister
    brother
    family
    romantic-man
    romantic-woman
  )

  @address_styles ~w(formal informal honorific casual)

  def relationship_types, do: @relationship_types
  def address_styles, do: @address_styles

  @doc false
  def changeset(user_relation, attrs) do
    user_relation
    |> cast(attrs, [
      :user_id,
      :target_user_id,
      :relationship_type,
      :description,
      :address_style,
      :nicknames
    ])
    |> validate_required([:user_id, :target_user_id])
    |> validate_inclusion(:relationship_type, @relationship_types)
    |> validate_inclusion(:address_style, @address_styles)
    |> validate_length(:description, max: 500)
    |> validate_nicknames()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:target_user_id)
    |> unique_constraint([:user_id, :target_user_id])
  end

  defp validate_nicknames(changeset) do
    nicknames = get_field(changeset, :nicknames) || []

    valid? =
      Enum.all?(nicknames, fn n ->
        is_binary(n) and String.trim(n) != "" and String.length(n) <= 50
      end)

    if valid? do
      changeset
    else
      add_error(changeset, :nicknames, "must be non-empty strings with a maximum length of 50")
    end
  end
end
