defmodule Medoru.Content.WordConjugation do
  @moduledoc """
  Schema for word conjugations.

  Stores all conjugated forms of words (verbs, adjectives) linked to their
  base dictionary form and grammar form (conjugation type).

  Example:
  - word_id -> "食べる" (dictionary form)
  - grammar_form_id -> "te-form"
  - conjugated_form -> "食べて"
  - reading -> "たべて"
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Content.{Word, GrammarForm}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_conjugations" do
    field :conjugated_form, :string
    field :reading, :string

    belongs_to :word, Word
    belongs_to :grammar_form, GrammarForm

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(conjugation, attrs) do
    conjugation
    |> cast(attrs, [:conjugated_form, :reading, :word_id, :grammar_form_id])
    |> validate_required([:conjugated_form, :word_id, :grammar_form_id])
    |> foreign_key_constraint(:word_id)
    |> foreign_key_constraint(:grammar_form_id)
    |> unique_constraint([:word_id, :grammar_form_id])
  end
end
