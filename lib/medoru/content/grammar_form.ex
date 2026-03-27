defmodule Medoru.Content.GrammarForm do
  @moduledoc """
  Schema for grammar forms (conjugations) for each word type.

  Examples:
  - Verbs: dictionary, masu-form, te-form, ta-form, nai-form, etc.
  - Adjectives: dictionary, adverbial, te-form, past, negative
  """
  use Ecto.Schema
  import Ecto.Changeset

  @word_types ["verb", "adjective", "noun"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "grammar_forms" do
    field :name, :string
    field :display_name, :string
    field :word_type, :string
    field :suffix_pattern, :string
    field :description, :string
    field :examples, {:array, :string}, default: []

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(grammar_form, attrs) do
    grammar_form
    |> cast(attrs, [:name, :display_name, :word_type, :suffix_pattern, :description, :examples])
    |> validate_required([:name, :display_name, :word_type])
    |> validate_inclusion(:word_type, @word_types)
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:display_name, min: 1, max: 100)
    |> unique_constraint([:name, :word_type])
  end
end
