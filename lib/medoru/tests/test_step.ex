defmodule Medoru.Tests.TestStep do
  @moduledoc """
  Schema for Test Steps - individual questions within a test.

  Step types:
  - :reading - Reading comprehension or kanji reading questions
  - :writing - Writing/typing questions
  - :listening - Audio-based questions
  - :grammar - Grammar questions
  - :speaking - Speaking/recording questions (future)
  - :vocabulary - Vocabulary recognition

  Question sub-types:
  - :multichoice - Multiple choice (1 point)
  - :fill - Fill in the blank (2 points)
  - :match - Matching pairs (1-2 points depending on complexity)
  - :order - Put in correct order (2 points)
  - :writing - Kanji writing with stroke validation (5 points)
  """
  use Ecto.Schema
  import Ecto.Changeset

  @step_types [:reading, :writing, :listening, :grammar, :speaking, :vocabulary]
  @question_types [:multichoice, :fill, :match, :order, :writing, :reading_text]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "test_steps" do
    field :order_index, :integer
    field :step_type, Ecto.Enum, values: @step_types
    field :question_type, Ecto.Enum, values: @question_types
    field :question, :string
    field :question_data, :map, default: %{}
    field :correct_answer, :string
    field :options, {:array, :string}, default: []
    field :points, :integer, default: 1
    field :hints, {:array, :string}, default: []
    field :explanation, :string
    field :time_limit_seconds, :integer

    # Content references (optional - for linking to specific kanji/words)
    belongs_to :kanji, Medoru.Content.Kanji
    belongs_to :word, Medoru.Content.Word

    belongs_to :test, Medoru.Tests.Test
    has_many :test_step_answers, Medoru.Tests.TestStepAnswer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(test_step, attrs) do
    test_step
    |> cast(attrs, [
      :order_index,
      :step_type,
      :question_type,
      :question,
      :question_data,
      :correct_answer,
      :options,
      :points,
      :hints,
      :explanation,
      :time_limit_seconds,
      :kanji_id,
      :word_id,
      :test_id
    ])
    |> validate_required([
      :order_index,
      :step_type,
      :question_type,
      :question,
      :correct_answer,
      :points,
      :test_id
    ])
    |> validate_inclusion(:step_type, @step_types)
    |> validate_inclusion(:question_type, @question_types)
    |> validate_number(:order_index, greater_than_or_equal_to: 0)
    |> validate_points_by_type()
    |> validate_multichoice_options()
    |> foreign_key_constraint(:test_id)
    |> foreign_key_constraint(:kanji_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:test_id, :order_index])
  end

  @doc """
  Returns the default points for a question type.
  """
  def default_points(question_type) do
    case question_type do
      :multichoice -> 1
      :fill -> 2
      :match -> 2
      :order -> 2
      :writing -> 5
      :reading_text -> 2
    end
  end

  defp validate_points_by_type(changeset) do
    question_type = get_field(changeset, :question_type)
    points = get_field(changeset, :points)

    case {question_type, points} do
      {:multichoice, p} when p != 1 ->
        add_error(changeset, :points, "multiple choice questions must be worth 1 point")

      {:writing, p} when p != 5 ->
        add_error(changeset, :points, "writing questions must be worth 5 points")

      {:reading_text, p} when p not in [1, 2] ->
        add_error(changeset, :points, "reading text questions must be worth 1 or 2 points")

      {:fill, p} when p not in [1, 2, 3] ->
        add_error(changeset, :points, "fill questions must be worth 2 or 3 points")

      {type, p} when type in [:match, :order] and p not in [1, 2] ->
        add_error(changeset, :points, "this question type must be worth 1 or 2 points")

      _ ->
        changeset
    end
  end

  defp validate_multichoice_options(changeset) do
    question_type = get_field(changeset, :question_type)
    options = get_field(changeset, :options) || []
    correct_answer = get_field(changeset, :correct_answer)

    case question_type do
      :multichoice ->
        changeset
        |> validate_multichoice_count(options)
        |> validate_correct_answer_in_options(options, correct_answer)

      _ ->
        changeset
    end
  end

  defp validate_multichoice_count(changeset, options) do
    count = length(options)

    cond do
      count < 4 ->
        add_error(changeset, :options, "multiple choice questions need at least 4 options")

      count > 8 ->
        add_error(changeset, :options, "multiple choice questions can have at most 8 options")

      true ->
        changeset
    end
  end

  defp validate_correct_answer_in_options(changeset, options, correct_answer) do
    if is_nil(correct_answer) or String.trim(correct_answer) == "" do
      add_error(changeset, :correct_answer, "correct answer is required")
    else
      trimmed_answer = String.trim(correct_answer)
      trimmed_options = Enum.map(options, &String.trim/1)

      if trimmed_answer not in trimmed_options do
        add_error(changeset, :correct_answer, "correct answer must be one of the options")
      else
        changeset
      end
    end
  end
end
