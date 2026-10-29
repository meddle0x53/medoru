defmodule Medoru.Content.KanjiExampleWord do
  @moduledoc """
  Join schema linking a kanji to admin-assigned example words.

  Example words are shown in kanji drawing challenges (Daily Kanji Test,
  Kanji Master) instead of the default frequency-based pick. `position`
  controls the display order; the lowest position is used for challenges.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kanji_example_words" do
    field :position, :integer, default: 0

    belongs_to :kanji, Medoru.Content.Kanji
    belongs_to :word, Medoru.Content.Word

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kanji_example_word, attrs) do
    kanji_example_word
    |> cast(attrs, [:position, :kanji_id, :word_id])
    |> validate_required([:position, :kanji_id, :word_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:kanji_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:kanji_id, :word_id])
  end
end
