defmodule Medoru.Content.KanjiReadingExtractor do
  @moduledoc """
  Extracts kanji readings from words by comparing kanji forms with hiragana readings.
  
  Uses a hybrid approach:
  1. Find matching kana prefix/suffix to isolate kanji portions
  2. For single kanji words, the entire remaining reading is the kanji reading
  3. For multi-kanji words, use known readings from database to segment
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji
  import Ecto.Query

  @doc """
  Extracts the reading for a specific kanji in a word.
  """
  def extract_reading(word_text, word_reading, kanji_character) do
    case extract_all_readings(word_text, word_reading) do
      {:ok, readings} -> Map.get(readings, kanji_character)
      {:error, _} -> nil
    end
  end

  @doc """
  Returns a map of all kanji readings for a word.
  """
  def extract_all_readings(word_text, word_reading) do
    text_chars = String.graphemes(word_text)
    reading_chars = String.graphemes(word_reading)
    
    # Find common prefix (kana at start)
    {_prefix, text_rest, reading_rest} = find_common_prefix(text_chars, reading_chars)
    
    # Find common suffix (kana at end, like okurigana)
    {_suffix, text_middle, reading_middle} = find_common_suffix(text_rest, reading_rest)
    
    # Now text_middle contains just kanji, reading_middle contains their readings
    readings = match_kanji_to_readings(text_middle, reading_middle)
    
    {:ok, readings}
  end

  # Finds common kana prefix between text and reading
  defp find_common_prefix(text, reading, acc \\ []) do
    case {text, reading} do
      {[t | t_rest], [r | r_rest]} when t == r ->
        if kanji?(t) do
          {Enum.reverse(acc), text, reading}
        else
          find_common_prefix(t_rest, r_rest, [t | acc])
        end
      
      _ ->
        {Enum.reverse(acc), text, reading}
    end
  end

  # Finds common kana suffix (okurigana)
  defp find_common_suffix(text, reading) do
    # Reverse both to find suffix
    text_rev = Enum.reverse(text)
    reading_rev = Enum.reverse(reading)
    
    {suffix_rev, text_mid_rev, reading_mid_rev} = find_common_prefix(text_rev, reading_rev)
    
    {Enum.reverse(suffix_rev), Enum.reverse(text_mid_rev), Enum.reverse(reading_mid_rev)}
  end

  # Matches kanji characters to their readings
  defp match_kanji_to_readings(text_chars, reading_chars) do
    kanji_list = Enum.filter(text_chars, &kanji?/1)
    
    cond do
      # No kanji - empty result
      kanji_list == [] ->
        %{}
      
      # Single kanji - entire reading belongs to it
      length(kanji_list) == 1 ->
        %{hd(kanji_list) => Enum.join(reading_chars)}
      
      # Multiple kanji - try to segment using known readings
      true ->
        segment_multi_kanji(kanji_list, reading_chars)
    end
  end

  # For multi-kanji words, try to segment the reading
  defp segment_multi_kanji(kanji_list, reading_chars) do
    reading = Enum.join(reading_chars)
    
    # Try each kanji's known readings to find segment boundaries
    Enum.reduce(kanji_list, {%{}, reading}, fn kanji, {acc, remaining} ->
      known = get_known_readings(kanji)
      
      # Find the longest known reading that matches the start of remaining
      case find_matching_reading(remaining, known) do
        nil -> 
          # No match - assign empty
          {Map.put(acc, kanji, ""), remaining}
        {match, rest} ->
          {Map.put(acc, kanji, match), rest}
      end
    end)
    |> elem(0)
  end

  # Gets known readings for a kanji from database
  defp get_known_readings(kanji_char) do
    from(k in Kanji,
      where: k.character == ^kanji_char,
      join: kr in assoc(k, :kanji_readings),
      select: kr.reading
    )
    |> Repo.all()
  end

  # Finds a known reading that matches the start of the word reading
  defp find_matching_reading(remaining, known_readings) do
    known_readings
    |> Enum.sort_by(&String.length/1, :desc)  # Longest first
    |> Enum.find_value(fn kr ->
      if String.starts_with?(remaining, kr) do
        rest = String.slice(remaining, String.length(kr)..-1)
        {kr, rest}
      else
        nil
      end
    end)
  end

  # Checks if a character is a CJK kanji
  def kanji?(char) do
    case String.to_charlist(char) do
      [cp] -> (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF)
      _ -> false
    end
  end
end
