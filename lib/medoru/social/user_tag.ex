defmodule Medoru.Social.UserTag do
  @moduledoc """
  Join schema linking users to their selected tags.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_tags" do
    belongs_to :user, Medoru.Accounts.User
    belongs_to :tag, Medoru.Social.Tag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_tag, attrs) do
    user_tag
    |> cast(attrs, [:user_id, :tag_id])
    |> validate_required([:user_id, :tag_id])
    |> unique_constraint([:user_id, :tag_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:tag_id)
  end
end
