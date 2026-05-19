defmodule Medoru.Content.GrammarLessonStep do
  @moduledoc """
  Schema for grammar lesson steps.

  Each step contains:
  - A grammar pattern (array of pattern elements)
  - An explanation of the grammar
  - Up to 5 examples with breakdowns
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Content.CustomLesson

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "grammar_lesson_steps" do
    field :position, :integer
    field :title, :string
    field :explanation, :string
    field :explanation_sections, {:array, :string}, default: []
    field :examples, {:array, :map}, default: []
    field :pattern_elements, {:array, :map}, default: []
    field :word_colors, {:array, :map}, default: []
    field :difficulty, :integer
    field :step_type, :string, default: "grammar"
    field :include_in_test, :boolean, default: false
    field :allows_student_validation, :boolean, default: false

    belongs_to :custom_lesson, CustomLesson

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :position,
      :title,
      :explanation,
      :explanation_sections,
      :examples,
      :pattern_elements,
      :word_colors,
      :difficulty,
      :step_type,
      :include_in_test,
      :allows_student_validation,
      :custom_lesson_id
    ])
    |> validate_required([:position, :custom_lesson_id])
    |> validate_inclusion(:step_type, ["grammar", "text"])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_step_fields()
    |> validate_word_colors()
    |> foreign_key_constraint(:custom_lesson_id)
  end

  defp validate_step_fields(changeset) do
    step_type = get_field(changeset, :step_type) || "grammar"

    case step_type do
      "grammar" ->
        changeset
        |> validate_examples()
        |> validate_pattern_elements()

      _ ->
        changeset
    end
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

  defp validate_pattern_elements(changeset) do
    validate_change(changeset, :pattern_elements, fn :pattern_elements, elements ->
      if Enum.empty?(elements) do
        [pattern_elements: "must have at least one pattern element"]
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
