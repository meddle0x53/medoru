defmodule Medoru.Content.WordClassMembership do
  @moduledoc """
  Join schema for words and word classes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Content.{Word, WordClass}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_class_memberships" do
    belongs_to :word, Word
    belongs_to :word_class, WordClass

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:word_id, :word_class_id])
    |> validate_required([:word_id, :word_class_id])
    |> foreign_key_constraint(:word_id)
    |> foreign_key_constraint(:word_class_id)
    |> unique_constraint([:word_id, :word_class_id])
  end
end
