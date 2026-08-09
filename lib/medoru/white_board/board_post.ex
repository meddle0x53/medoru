defmodule Medoru.WhiteBoard.BoardPost do
  @moduledoc """
  Schema for white board posts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "board_posts" do
    field :title, :string
    field :content, :string
    field :visibility, :string, default: "public"
    field :post_type, :string, default: "text"
    field :canvas_data, :map
    field :card_data, :map

    belongs_to :user, Medoru.Accounts.User
    has_many :comments, Medoru.WhiteBoard.BoardComment, foreign_key: :post_id
    has_many :reactions, Medoru.WhiteBoard.BoardReaction, foreign_key: :post_id

    timestamps(type: :utc_datetime)
  end

  @visibilities ["public", "followers"]
  @post_types ["text", "canvas", "word_card"]

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:user_id, :title, :content, :visibility, :post_type, :canvas_data, :card_data])
    |> validate_required([:user_id, :visibility, :post_type])
    |> validate_inclusion(:visibility, @visibilities)
    |> validate_inclusion(:post_type, @post_types)
    |> validate_length(:title, max: 200)
    |> validate_content_for_type()
  end

  defp validate_content_for_type(changeset) do
    case get_field(changeset, :post_type) do
      "text" ->
        changeset
        |> validate_required([:content])
        |> validate_length(:content, max: 5000)

      "canvas" ->
        changeset
        |> validate_required([:canvas_data])

      "word_card" ->
        changeset
        |> validate_required([:card_data])
        |> validate_change(:card_data, fn :card_data, data ->
          if is_map(data) and is_map(data["word"]) and is_binary(data["word"]["text"]) do
            []
          else
            [card_data: "must contain a word snapshot"]
          end
        end)

      _ ->
        changeset
    end
  end
end
