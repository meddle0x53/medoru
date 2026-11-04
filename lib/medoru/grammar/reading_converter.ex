defmodule Medoru.Grammar.ReadingConverter do
  @moduledoc """
  Converts Japanese sentences to kana-only reading strings.

  Used for grading "make a question and answer it" test steps: both the
  expected answers and the student input are converted to kana readings and
  compared after punctuation/whitespace normalization.
  """

  import Ecto.Query

  alias Medoru.Content.{Kanji, KanjiReading, Word}
  alias Medoru.Repo

  @punctuation_pattern ~r/[\s。、！？!?,.・]+/u

  # Katakana (ァ-ヶ) mapped to hiragana by subtracting 0x60 so that
  # katakana/hiragana spellings of the same word compare equal.
  @spec normalize_for_comparison(String.t()) :: String.t()
  def normalize_for_comparison(sentence) when is_binary(sentence) do
    sentence
    |> to_kana()
    |> String.replace(@punctuation_pattern, "")
    |> katakana_to_hiragana()
  end

  def normalize_for_comparison(_), do: ""

  defp katakana_to_hiragana(string) do
    string
    |> String.to_charlist()
    |> Enum.map_join(fn
      cp when cp >= 0x30A1 and cp <= 0x30F6 -> <<cp - 0x60::utf8>>
      cp -> <<cp::utf8>>
    end)
  end

  @doc """
  Converts a Japanese sentence to a kana-only reading string.

  Uses greedy longest-match segmentation against the words dictionary, so
  on'yomi compounds like 空港 resolve to their word reading (くうこう)
  instead of per-kanji kun'yomi guesses. Fallback for unmatched kanji is
  per-kanji readings from `kanji_readings` (kun'yomi preferred, then
  on'yomi); kanji without any reading are kept as-is. Kana passes through;
  punctuation is dropped.
  """
  @spec to_kana(String.t()) :: String.t()
  def to_kana(sentence) when is_binary(sentence) do
    sentence
    |> String.graphemes()
    |> greedy_to_kana([])
  end

  def to_kana(_), do: ""

  @max_word_length 8

  defp greedy_to_kana([], acc), do: acc |> Enum.reverse() |> Enum.join()

  defp greedy_to_kana([char | rest] = chars, acc) do
    cond do
      kana?(char) ->
        greedy_to_kana(rest, [char | acc])

      kanji?(char) ->
        {reading, remaining} = take_longest_word(chars)
        greedy_to_kana(remaining, [reading | acc])

      true ->
        # Punctuation, symbols, whitespace: dropped.
        greedy_to_kana(rest, acc)
    end
  end

  # Tries progressively shorter prefixes of the remaining characters as
  # whole-word lookups (so 空港 -> くうこう, 行く -> いく); falls back to a
  # single kanji's reading when no word matches.
  defp take_longest_word(chars) do
    limit = min(length(chars), @max_word_length)

    matched =
      Enum.reduce_while(limit..1//-1, nil, fn len, _acc ->
        candidate = chars |> Enum.take(len) |> Enum.join()

        case lookup_word_reading(candidate) do
          nil -> {:cont, nil}
          reading -> {:halt, {reading, Enum.drop(chars, len)}}
        end
      end)

    case matched do
      nil ->
        [char | rest] = chars
        {lookup_kanji_reading(char) || char, rest}

      result ->
        result
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
