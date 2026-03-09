# Script to calculate sort_score for existing words
#
#     mix run priv/repo/calculate_sort_scores.exs

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.Word

IO.puts("Calculating sort_score for all words...")

# Helper to extract kanji from text
extract_kanji_chars = fn text ->
  text
  |> String.graphemes()
  |> Enum.filter(fn char ->
    code = String.to_charlist(char) |> hd()
    code >= 0x4E00 and code <= 0x9FFF
  end)
end

# Calculate sort score for lesson ordering
calculate_sort_score = fn text, frequency ->
  kanji_chars = extract_kanji_chars.(text)
  kanji_count = length(kanji_chars)
  kana_count = String.length(text) - kanji_count
  
  # Complexity tier based on visual pattern:
  # (1,0), (1,1), (1,2), (2,0), (2,1), (1,3), (2,2), (3,0), (3,1), ...
  complexity_tier = 
    case {kanji_count, kana_count} do
      {1, 0} -> 1
      {1, 1} -> 2
      {1, 2} -> 3
      {2, 0} -> 4
      {2, 1} -> 5
      {1, 3} -> 6
      {2, 2} -> 7
      {3, 0} -> 8
      {3, 1} -> 9
      {1, 4} -> 10
      {2, 3} -> 11
      {3, 2} -> 12
      {4, 0} -> 13
      {4, 1} -> 14
      {k, n} -> k * 10 + n
    end
  
  # Final score: frequency * 100 + complexity
  # Groups by frequency band first, then complexity within band
  (frequency || 1000) * 100 + complexity_tier
end

# Get all words without sort_score
words = 
  Word
  |> where([w], is_nil(w.sort_score))
  |> Repo.all()

IO.puts("Processing #{length(words)} words without sort_score...")

# Update in batches
words
|> Enum.chunk_every(1000)
|> Enum.with_index()
|> Enum.each(fn {batch, idx} ->
  Enum.each(batch, fn word ->
    sort_score = calculate_sort_score.(word.text, word.usage_frequency)
    
    word
    |> Ecto.Changeset.change(sort_score: sort_score)
    |> Repo.update!()
  end)
  
  if rem(idx, 10) == 0 do
    IO.puts("  Processed #{(idx + 1) * 1000} words...")
  end
end)

IO.puts("✅ Done!")

# Show sample of N5 words sorted by sort_score
IO.puts("\nSample N5 words (sorted by sort_score):")
sample = 
  from(w in Word, 
    where: w.difficulty == 5,
    order_by: [asc: w.sort_score],
    limit: 20,
    select: {w.text, w.reading, w.usage_frequency, w.sort_score}
  )
  |> Repo.all()

Enum.each(sample, fn {text, reading, freq, score} ->
  IO.puts("  #{text} (#{reading}) freq=#{freq}, score=#{score}")
end)
