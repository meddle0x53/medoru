defmodule Medoru.Accounts.User do
  @moduledoc """
  User schema for OAuth authentication.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type_values ["student", "teacher", "admin"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :provider, :string
    field :provider_uid, :string
    field :name, :string
    field :avatar_url, :string
    field :type, :string, default: "student"

    has_one :profile, Medoru.Accounts.UserProfile
    has_one :stats, Medoru.Accounts.UserStats

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :provider, :provider_uid, :name, :avatar_url, :type])
    |> validate_required([:email, :provider, :provider_uid])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:provider, ["google"])
    |> validate_inclusion(:type, @type_values)
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_uid],
      name: :users_provider_provider_uid_index,
      message: "account already exists"
    )
  end

  @doc """
  Changeset for updating user type (admin only).
  """
  def type_changeset(user, attrs) do
    user
    |> cast(attrs, [:type])
    |> validate_required([:type])
    |> validate_inclusion(:type, @type_values)
  end

  @doc """
  Returns true if user is an admin.
  """
  def admin?(%__MODULE__{type: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Returns true if user is a teacher (includes admins).
  """
  def teacher?(%__MODULE__{type: "teacher"}), do: true
  def teacher?(%__MODULE__{type: "admin"}), do: true
  def teacher?(_), do: false

  @doc """
  Returns true if user is a student.
  """
  def student?(%__MODULE__{type: "student"}), do: true
  def student?(_), do: false

  @doc """
  Returns list of valid user types.
  """
  def types, do: @type_values
end
