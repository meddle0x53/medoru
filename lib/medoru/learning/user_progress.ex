defmodule Medoru.Learning.UserProgress do
  @moduledoc """
  Schema for tracking user progress on individual kanji and words.
  Mastery levels: 0=New, 1-3=Learning, 4=Mastered
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_progress" do
    field :mastery_level, :integer, default: 0
    field :times_reviewed, :integer, default: 0
    field :known_score, :integer, default: 0
    field :last_reviewed_at, :utc_datetime
    field :next_review_at, :utc_datetime

    belongs_to :user, Medoru.Accounts.User
    belongs_to :kanji, Medoru.Content.Kanji
    belongs_to :word, Medoru.Content.Word
    belongs_to :grammar_definition, Medoru.Content.GrammarDefinition
    has_one :review_schedule, Medoru.Learning.ReviewSchedule

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_progress, attrs) do
    user_progress
    |> cast(attrs, [
      :mastery_level,
      :times_reviewed,
      :known_score,
      :last_reviewed_at,
      :next_review_at,
      :user_id,
      :kanji_id,
      :word_id,
      :grammar_definition_id
    ])
    |> validate_required([:user_id])
    |> validate_exactly_one_content()
    |> validate_number(:mastery_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:times_reviewed, greater_than_or_equal_to: 0)
    |> validate_number(:known_score, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:kanji_id)
    |> foreign_key_constraint(:word_id)
    |> foreign_key_constraint(:grammar_definition_id)
    |> unique_constraint([:user_id, :kanji_id], name: :user_progress_user_id_kanji_id_index)
    |> unique_constraint([:user_id, :word_id], name: :user_progress_user_id_word_id_index)
    |> unique_constraint([:user_id, :grammar_definition_id], name: :user_progress_user_id_grammar_definition_id_index)
  end

  defp validate_exactly_one_content(changeset) do
    kanji_id = get_field(changeset, :kanji_id)
    word_id = get_field(changeset, :word_id)
    grammar_definition_id = get_field(changeset, :grammar_definition_id)

    present_count = Enum.count([kanji_id, word_id, grammar_definition_id], & &1)

    cond do
      present_count == 0 ->
        add_error(changeset, :kanji_id, "must have either kanji_id, word_id, or grammar_definition_id")

      present_count == 1 ->
        changeset

      present_count > 1 ->
        add_error(changeset, :kanji_id, "cannot have more than one content type")
    end
  end
end
