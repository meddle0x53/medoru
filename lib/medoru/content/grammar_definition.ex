defmodule Medoru.Content.GrammarDefinition do
  @moduledoc """
  Schema for grammar definitions — core reference data for Japanese grammar points.

  Each grammar definition contains:
  - A title and slug
  - An entry type: "pattern" (validated practice entry) or "text" (informational)
  - A pattern (array of pattern elements like word slots and literals) —
    required for "pattern" entries, optional and presentational for "text" entries
  - Word colors for highlighting
  - A markdown description and optional markdown explanation sections
  - Up to 5 examples (sentence, reading, meaning)
  - JLPT level (N1-N5)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "grammar_definitions" do
    field :title, :string
    field :slug, :string
    field :pattern_elements, {:array, :map}, default: []
    field :word_colors, {:array, :map}, default: []
    field :description, :string
    field :description_bg, :string
    field :description_ja, :string
    field :explanation_sections, {:array, :string}, default: []
    field :entry_type, :string, default: "pattern"
    field :examples, {:array, :map}, default: []
    field :jlpt_level, :integer
    field :frequency, :integer, default: 1000

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(grammar_definition, attrs) do
    grammar_definition
    |> cast(attrs, [
      :title,
      :slug,
      :pattern_elements,
      :word_colors,
      :description,
      :description_bg,
      :description_ja,
      :explanation_sections,
      :entry_type,
      :examples,
      :jlpt_level,
      :frequency
    ])
    |> maybe_generate_slug()
    |> validate_required([:title, :slug])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:jlpt_level, 1..5)
    |> validate_inclusion(:entry_type, ["pattern", "text"])
    |> validate_number(:frequency, greater_than_or_equal_to: 0)
    |> validate_examples()
    |> validate_pattern_elements()
    |> validate_explanation_sections()
    |> validate_word_colors()
    |> unique_constraint(:title)
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, generate_slug(title))
        end

      _ ->
        changeset
    end
  end

  defp generate_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 100)
  end

  defp validate_examples(changeset) do
    validate_change(changeset, :examples, fn :examples, examples ->
      cond do
        length(examples) > 5 ->
          [examples: "can have at most 5 examples"]

        Enum.any?(examples, &invalid_example?/1) ->
          [examples: "each example must have sentence, reading, and meaning"]

        true ->
          []
      end
    end)
  end

  defp invalid_example?(example) do
    not is_map(example) or
      is_nil(example["sentence"]) or
      is_nil(example["reading"]) or
      is_nil(example["meaning"])
  end

  @doc """
  Returns the localized description for the given locale.
  Falls back to English description, then empty string.
  """
  def localized_description(%__MODULE__{} = gd, locale) do
    case locale do
      "bg" -> gd.description_bg || gd.description || ""
      "ja" -> gd.description_ja || gd.description || ""
      _ -> gd.description || ""
    end
  end

  @doc """
  Returns the localized meaning for an example.
  Falls back to English meaning, then empty string.
  """
  def localized_example_meaning(example, locale) when is_map(example) do
    case locale do
      "bg" -> example["meaning_bg"] || example["meaning"] || ""
      "ja" -> example["meaning_ja"] || example["meaning"] || ""
      _ -> example["meaning"] || ""
    end
  end

  defp validate_pattern_elements(changeset) do
    entry_type = get_field(changeset, :entry_type, "pattern")
    elements = get_field(changeset, :pattern_elements) || []

    # "pattern" entries must have at least one pattern element; "text" entries
    # may carry an optional pattern for display only (never used for validation).
    if entry_type == "pattern" and Enum.empty?(elements) do
      add_error(changeset, :pattern_elements, "must have at least one pattern element")
    else
      changeset
    end
  end

  defp validate_explanation_sections(changeset) do
    validate_change(changeset, :explanation_sections, fn :explanation_sections, sections ->
      invalid? =
        not is_list(sections) or
          Enum.any?(sections, fn section -> not is_binary(section) end) or
          Enum.any?(sections, &(String.length(&1) > 10_000))

      if invalid? do
        [explanation_sections: "each section must be a string of at most 10000 characters"]
      else
        []
      end
    end)
  end

  defp validate_word_colors(changeset) do
    validate_change(changeset, :word_colors, fn :word_colors, colors ->
      invalid? =
        Enum.any?(colors, fn color ->
          not is_map(color) or
            is_nil(color["word"]) or
            is_nil(color["color_index"]) or
            not is_integer(color["color_index"]) or
            color["color_index"] < 0 or
            color["color_index"] > 31 or
            is_nil(color["apply_to"]) or
            color["apply_to"] not in ["examples", "explanation", "both"]
        end)

      if invalid? do
        [word_colors: "each entry must have word, color_index (0-31), and apply_to"]
      else
        []
      end
    end)
  end
end
