defmodule Medoru.Social.ProfileVisit do
  @moduledoc """
  Schema for tracking profile visits.

  Each row records the most recent time a user visited another user's profile.
  Repeated visits by the same visitor update the existing row via upsert.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "profile_visits" do
    belongs_to :visitor, Medoru.Accounts.User
    belongs_to :visited_user, Medoru.Accounts.User
    field :visited_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile_visit, attrs) do
    profile_visit
    |> cast(attrs, [:visitor_id, :visited_user_id, :visited_at])
    |> validate_required([:visitor_id, :visited_user_id, :visited_at])
    |> foreign_key_constraint(:visitor_id)
    |> foreign_key_constraint(:visited_user_id)
    |> unique_constraint([:visitor_id, :visited_user_id])
    |> check_constraint(:visitor_id,
      name: :cannot_visit_self,
      message: "cannot visit your own profile"
    )
  end
end
