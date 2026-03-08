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
  """
  use Ecto.Schema
  import Ecto.Changeset

  @step_types [:reading, :writing, :listening, :grammar, :speaking, :vocabulary]
  @question_types [:multichoice, :fill, :match, :order]

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
    end
  end

  defp validate_points_by_type(changeset) do
    question_type = get_field(changeset, :question_type)
    points = get_field(changeset, :points)

    case {question_type, points} do
      {:multichoice, p} when p != 1 ->
        add_error(changeset, :points, "multiple choice questions must be worth 1 point")

      {type, p} when type in [:fill, :match, :order] and p not in [1, 2] ->
        add_error(changeset, :points, "this question type must be worth 1 or 2 points")

      _ ->
        changeset
    end
  end

  defp validate_multichoice_options(changeset) do
    question_type = get_field(changeset, :question_type)
    options = get_field(changeset, :options)

    case question_type do
      :multichoice ->
        if is_nil(options) or length(options) < 2 do
          add_error(changeset, :options, "multiple choice questions need at least 2 options")
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
