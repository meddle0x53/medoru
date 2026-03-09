# Script to populate word_kanjis table by analyzing word text
# This links words to their constituent kanji characters
#
#     mix run priv/repo/populate_word_kanjis.exs

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.{Word, Kanji, WordKanji}

IO.puts("Populating word_kanjis table...")

# Get all kanji for lookup
kanji_map = 
  Kanji
  |> Repo.all()
  |> Map.new(fn k -> {k.character, k} end)

IO.puts("Loaded #{map_size(kanji_map)} kanji")

# Get all words that don't have word_kanjis yet
words_with_kanjis = 
  from(wk in WordKanji, select: wk.word_id, distinct: true)
  |> Repo.all()
  |> MapSet.new()

words = 
  Word
  |> where([w], w.id not in ^MapSet.to_list(words_with_kanjis))
  |> Repo.all()

IO.puts("Processing #{length(words)} words without kanji links...")

# Helper to extract kanji characters from text
extract_kanji = fn text ->
  text
  |> String.graphemes()
  |> Enum.with_index()
  |> Enum.filter(fn {char, _idx} -> 
    code = String.to_charlist(char) |> hd()
    # CJK Unified Ideographs range
    code >= 0x4E00 and code <= 0x9FFF
  end)
end

# Process each word
{created, skipped} = 
  Enum.reduce(words, {0, 0}, fn word, {created, skipped} ->
    kanji_chars = extract_kanji.(word.text)
    
    if kanji_chars == [] do
      # Kana-only word, skip
      {created, skipped + 1}
    else
      # Create word_kanji links
      links = 
        Enum.map(kanji_chars, fn {char, position} ->
          case Map.get(kanji_map, char) do
            nil -> 
              # Kanji not in database
              nil
            kanji ->
              %{
                word_id: word.id,
                kanji_id: kanji.id,
                position: position,
                kanji_reading_id: nil,  # We'll set this later if needed
                inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
                updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
              }
          end
        end)
        |> Enum.reject(&is_nil/1)
      
      if links == [] do
        {created, skipped + 1}
      else
        # Insert all links for this word
        Repo.insert_all(WordKanji, links)
        {created + length(links), skipped}
      end
    end
  end)

IO.puts("")
IO.puts("✅ Complete!")
IO.puts("  Created: #{created} word-kanji links")
IO.puts("  Skipped: #{skipped} words (kana-only or unknown kanji)")

# Show final count
total = Repo.aggregate(WordKanji, :count, :id)
IO.puts("  Total word_kanjis: #{total}")
