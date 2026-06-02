defmodule Medoru.WhiteBoard.BoardComment do
  @moduledoc """
  Schema for white board post comments.
  Supports nested replies via parent_id.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "board_comments" do
    field :content, :string

    belongs_to :post, Medoru.WhiteBoard.BoardPost
    belongs_to :user, Medoru.Accounts.User
    belongs_to :parent_comment, Medoru.WhiteBoard.BoardComment, foreign_key: :parent_id
    has_many :replies, Medoru.WhiteBoard.BoardComment, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:post_id, :user_id, :parent_id, :content])
    |> validate_required([:post_id, :user_id, :content])
    |> validate_length(:content, min: 1, max: 2000)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_id)
  end
end
