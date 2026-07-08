defmodule Medoru.Content.WordRelation do
  @moduledoc """
  Schema for relationships between words: synonyms, antonyms, and expressions.

  A relation always belongs to a source `word`. When `related_word_id` is set,
  the target word exists in the database and can be linked. When it is `nil`,
  `expression_text` holds a plain-text reference (useful for expressions that
  have not been added as words yet).

  `status` tracks the admin review lifecycle:
    - `pending`  – proposed by AI, awaiting admin approval
    - `approved` – approved by an admin and visible to users
    - `rejected` – rejected by an admin and ignored
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @relation_types [
    :synonym,
    :antonym,
    :expression
  ]

  @statuses [
    :pending,
    :approved,
    :rejected
  ]

  schema "word_relations" do
    field :relation_type, Ecto.Enum, values: @relation_types
    field :expression_text, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending

    belongs_to :word, Medoru.Content.Word
    belongs_to :related_word, Medoru.Content.Word

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(word_relation, attrs) do
    word_relation
    |> cast(attrs, [:word_id, :related_word_id, :relation_type, :expression_text, :status])
    |> validate_required([:word_id, :relation_type])
    |> validate_relation_type()
    |> foreign_key_constraint(:word_id)
    |> foreign_key_constraint(:related_word_id)
  end

  # Expressions may be text-only; synonyms and antonyms must link to another word.
  defp validate_relation_type(changeset) do
    relation_type = get_field(changeset, :relation_type)
    related_word_id = get_field(changeset, :related_word_id)
    expression_text = get_field(changeset, :expression_text)

    cond do
      relation_type in [:synonym, :antonym] and is_nil(related_word_id) ->
        add_error(changeset, :related_word_id, "is required for synonyms and antonyms")

      relation_type == :expression and is_nil(related_word_id) and is_nil(expression_text) ->
        add_error(
          changeset,
          :expression_text,
          "is required when expression is not linked to a word"
        )

      true ->
        changeset
    end
  end
end
