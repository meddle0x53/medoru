defmodule Medoru.Social.UserBlock do
  @moduledoc """
  Schema for user blocks.
  A block is unidirectional: blocker cannot see/interact with blocked user.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_blocks" do
    field :reason, :string
    field :blocked_at, :utc_datetime

    belongs_to :blocker, Medoru.Accounts.User
    belongs_to :blocked, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_block, attrs) do
    user_block
    |> cast(attrs, [:reason, :blocked_at, :blocker_id, :blocked_id])
    |> validate_required([:blocked_at, :blocker_id, :blocked_id])
    |> foreign_key_constraint(:blocker_id)
    |> foreign_key_constraint(:blocked_id)
    |> unique_constraint([:blocker_id, :blocked_id],
      name: :user_blocks_blocker_id_blocked_id_index,
      message: "already blocked"
    )
  end
end
