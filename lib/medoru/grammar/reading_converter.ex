defmodule Medoru.Grammar.ReadingConverter do
  @moduledoc """
  Converts Japanese sentences to kana-only reading strings.

  Used for grading "make a question and answer it" test steps: both the
  expected answers and the student input are converted to kana readings and
  compared after punctuation/whitespace normalization.
  """

  import Ecto.Query

  alias Medoru.Content.{Kanji, KanjiReading, Word}
  alias Medoru.Grammar.Tokenizer
  alias Medoru.Repo

  @punctuation_pattern ~r/[\s。、！？!?,.・]+/u

  @doc """
  Converts a Japanese sentence to a kana-only reading string.

  1. Tokenizes with `Medoru.Grammar.Tokenizer`.
  2. Known words (dictionary or conjugated forms) use the word's reading.
  3. Unknown words fall back to per-kanji readings from `kanji_readings`
     (kun'yomi preferred, then on'yomi). Kanji without any reading are
     kept as-is.
  4. Kana passes through; punctuation is dropped.
  """
  @spec to_kana(String.t()) :: String.t()
  def to_kana(sentence) when is_binary(sentence) do
    sentence
    |> Tokenizer.tokenize()
    |> Enum.map_join(&token_to_kana/1)
  end

  def to_kana(_), do: ""

  @doc """
  Returns the kana reading with all punctuation (Japanese and ASCII) and
  whitespace stripped. This is the form used for grading comparisons.
  """
  @spec normalize_for_comparison(String.t()) :: String.t()
  def normalize_for_comparison(sentence) when is_binary(sentence) do
    sentence
    |> to_kana()
    |> String.replace(@punctuation_pattern, "")
  end

  def normalize_for_comparison(_), do: ""

  defp token_to_kana(%{word_id: word_id, text: text}) when is_binary(word_id) do
    case Repo.get(Word, word_id) do
      %Word{reading: reading} when is_binary(reading) and reading != "" ->
        if contains_kanji?(reading), do: chars_to_kana(text), else: reading

      _ ->
        chars_to_kana(text)
    end
  end

  defp token_to_kana(%{text: text}), do: chars_to_kana(text)

  # Tries the whole surface form as a word first, then falls back to
  # per-character readings.
  defp chars_to_kana(text) do
    case lookup_word_reading(text) do
      nil -> Enum.map_join(String.graphemes(text), &char_to_kana/1)
      reading -> reading
    end
  end

  defp lookup_word_reading(text) do
    reading =
      Word
      |> where([w], w.text == ^text)
      |> select([w], w.reading)
      |> limit(1)
      |> Repo.one()

    case reading do
      r when is_binary(r) and r != "" ->
        if contains_kanji?(r), do: nil, else: r

      _ ->
        nil
    end
  end

  defp char_to_kana(char) do
    cond do
      kana?(char) ->
        char

      kanji?(char) ->
        lookup_kanji_reading(char) || char

      true ->
        ""
    end
  end

  # Kun readings are preferred since vocabulary words most often use kun'yomi.
  defp lookup_kanji_reading(char) do
    KanjiReading
    |> join(:inner, [kr], k in Kanji, on: kr.kanji_id == k.id)
    |> where([kr, k], k.character == ^char)
    |> order_by([kr], fragment("CASE WHEN ? = 'kun' THEN 0 ELSE 1 END", kr.reading_type))
    |> select([kr], kr.reading)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      reading -> reading |> String.split(".") |> List.first()
    end
  end

  defp kana?(<<cp::utf8>>), do: (cp >= 0x3040 and cp <= 0x309F) or (cp >= 0x30A0 and cp <= 0x30FF)
  defp kana?(_), do: false

  defp kanji?(<<cp::utf8>>), do: cp >= 0x4E00 and cp <= 0x9FFF
  defp kanji?(_), do: false

  defp contains_kanji?(text) do
    text
    |> String.to_charlist()
    |> Enum.any?(fn cp -> cp >= 0x4E00 and cp <= 0x9FFF end)
  end
end
