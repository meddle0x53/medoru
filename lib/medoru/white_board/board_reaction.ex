defmodule Medoru.WhiteBoard.BoardReaction do
  @moduledoc """
  Schema for white board post reactions.
  One reaction per user per post.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "board_reactions" do
    field :emoji, :string

    belongs_to :post, Medoru.WhiteBoard.BoardPost
    belongs_to :user, Medoru.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:post_id, :user_id, :emoji])
    |> validate_required([:post_id, :user_id, :emoji])
    |> validate_length(:emoji, min: 1, max: 10)
    |> unique_constraint([:post_id, :user_id, :emoji],
      name: :board_reactions_post_id_user_id_emoji_index,
      message: "already reacted"
    )
  end
end
