defmodule Medoru.Content.WordKanji do
  @moduledoc """
  Join schema linking words to their constituent kanji.
  Each WordKanji record represents one kanji character in a word,
  referencing both the kanji and the specific reading used.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_kanjis" do
    field :position, :integer

    belongs_to :word, Medoru.Content.Word
    belongs_to :kanji, Medoru.Content.Kanji
    belongs_to :kanji_reading, Medoru.Content.KanjiReading

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(word_kanji, attrs) do
    word_kanji
    |> cast(attrs, [:position, :word_id, :kanji_id, :kanji_reading_id])
    |> validate_required([:position, :word_id, :kanji_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:word_id)
    |> foreign_key_constraint(:kanji_id)
    |> foreign_key_constraint(:kanji_reading_id)
    |> unique_constraint([:word_id, :kanji_id, :position],
      name: :word_kanjis_word_id_kanji_id_position_index
    )
  end
end
