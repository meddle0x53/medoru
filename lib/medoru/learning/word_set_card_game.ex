defmodule Medoru.Learning.WordSetCardGame do
  @moduledoc """
  Schema for a word set memory card game.

  Each word set can have at most one card game (enforced by a unique index on
  `word_set_id`). The game's words are snapshotted at creation time into the
  `words` JSONB column, so later edits to the word set do not affect the game.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Learning.WordSet

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_set_card_games" do
    field :words, {:array, :map}, default: []

    belongs_to :word_set, WordSet
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_set_card_game, attrs) do
    word_set_card_game
    |> cast(attrs, [:words, :word_set_id, :user_id])
    |> validate_required([:words, :word_set_id, :user_id])
    |> unique_constraint(:word_set_id)
    |> foreign_key_constraint(:word_set_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Converts the stored JSONB word snapshots (string keys) into maps with atom
  keys matching the fields the card game render expects (`:id`, `:text`,
  `:reading`, `:meaning`, `:translations`).
  """
  def snapshot_words(%__MODULE__{words: words}) do
    Enum.map(words, &atomize_word/1)
  end

  defp atomize_word(word) when is_map(word) do
    Map.new(word, fn {key, value} -> {safe_atom(key), value} end)
  end

  defp safe_atom(key) when is_atom(key), do: key

  defp safe_atom(key) when is_binary(key) do
    if key in ~w(id text reading meaning translations) do
      String.to_existing_atom(key)
    else
      key
    end
  end
end
