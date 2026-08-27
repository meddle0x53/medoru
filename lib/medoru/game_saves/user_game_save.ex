defmodule Medoru.GameSaves.UserGameSave do
  @moduledoc """
  Schema for a persisted Hollow Ouroboros save blob.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_game_saves" do
    field :save_data, :map
    field :version, :integer, default: 1

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(user_game_save, attrs) do
    user_game_save
    |> cast(attrs, [:save_data, :version, :user_id])
    |> validate_required([:save_data, :version, :user_id])
    |> validate_number(:version, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:user_id)
  end
end
