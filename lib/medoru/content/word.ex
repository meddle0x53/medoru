defmodule Medoru.Content.Word do
  @moduledoc """
  Schema for Japanese words/vocabulary.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @word_types [:noun, :verb, :adjective, :adverb, :particle, :pronoun, :counter, :expression, :other]

  schema "words" do
    field :text, :string
    field :meaning, :string
    field :reading, :string
    field :difficulty, :integer
    field :usage_frequency, :integer, default: 1000
    field :word_type, Ecto.Enum, values: @word_types, default: :other

    has_many :word_kanjis, Medoru.Content.WordKanji, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(word, attrs) do
    word
    |> cast(attrs, [:text, :meaning, :reading, :difficulty, :usage_frequency, :word_type])
    |> validate_required([:text, :meaning, :reading, :difficulty])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:usage_frequency, greater_than: 0)
    |> validate_word_text()
    |> validate_reading()
    |> unique_constraint(:text)
  end

  # Validate that word text contains valid Japanese characters
  # (kanji, hiragana, katakana, and common punctuation)
  defp validate_word_text(changeset) do
    validate_change(changeset, :text, fn :text, value ->
      if valid_japanese_text?(value) do
        []
      else
        [text: "must contain valid Japanese characters"]
      end
    end)
  end

  # Validate that reading is valid hiragana/katakana
  defp validate_reading(changeset) do
    validate_change(changeset, :reading, fn :reading, value ->
      if valid_kana_only?(value) do
        []
      else
        [reading: "must contain only hiragana or katakana"]
      end
    end)
  end

  # Check if text contains valid Japanese characters:
  # - CJK Unified Ideographs (kanji): U+4E00-U+9FFF, U+3400-U+4DBF
  # - Hiragana: U+3040-U+309F
  # - Katakana: U+30A0-U+30FF
  # - Common punctuation: U+3000-U+303F (CJK symbols/punctuation)
  # - Prolonged sound mark: U+30FC (ー)
  defp valid_japanese_text?(text) do
    String.to_charlist(text)
    |> Enum.all?(fn cp ->
      (cp >= 0x4E00 and cp <= 0x9FFF) or
        (cp >= 0x3400 and cp <= 0x4DBF) or
        (cp >= 0x3040 and cp <= 0x309F) or
        (cp >= 0x30A0 and cp <= 0x30FF) or
        (cp >= 0x3000 and cp <= 0x303F) or
        cp == 0x30FC
    end)
  end

  # Check if text contains only kana (hiragana/katakana)
  defp valid_kana_only?(text) do
    String.to_charlist(text)
    |> Enum.all?(fn cp ->
      (cp >= 0x3040 and cp <= 0x309F) or
        (cp >= 0x30A0 and cp <= 0x30FF) or
        cp == 0x30FC
    end)
  end
end
