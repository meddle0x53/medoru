#!/usr/bin/env elixir
# Script: Adjust word difficulty based on kanji difficulty
# 
# Logic:
# - N2 words containing N1 kanji -> become N1
# - N3 words containing N1 kanji -> become N1  
# - N3 words containing N2 kanji (but no N1) -> become N2
#
# Note: N1 is the MOST difficult, N5 is the EASIEST
#
# Usage: mix run priv/repo/adjust_word_difficulty.exs

alias Medoru.Repo
alias Medoru.Content.{Word, WordKanji, Kanji}
import Ecto.Query

IO.puts("Adjusting word difficulty based on kanji composition...")
IO.puts("=" |> String.duplicate(60))

# Get all N2 and N3 words with their kanji
words_with_kanji =
  (from(w in Word,
    join: wk in WordKanji, on: wk.word_id == w.id,
    join: k in Kanji, on: wk.kanji_id == k.id,
    where: w.difficulty in [2, 3],
    select: %{
      word_id: w.id,
      word_text: w.text,
      word_difficulty: w.difficulty,
      kanji_id: k.id,
      kanji_character: k.character,
      kanji_level: k.jlpt_level
    }
  )
  |> Repo.all())

# Group by word
words_by_id = Enum.group_by(words_with_kanji, & &1.word_id)

IO.puts("Found #{map_size(words_by_id)} N2/N3 words to analyze\n")

# Collect word IDs for each adjustment category using reduce
{n1_from_n2, n1_from_n3, n2_from_n3} =
  Enum.reduce(words_by_id, {[], [], []}, fn {word_id, kanji_list}, {n2to1, n3to1, n3to2} ->
    word_difficulty = hd(kanji_list).word_difficulty
    # N1=1 is most difficult, N5=5 is easiest
    max_kanji_difficulty = Enum.min_by(kanji_list, & &1.kanji_level).kanji_level
    
    cond do
      # Contains N1 kanji (hardest)
      max_kanji_difficulty == 1 and word_difficulty == 2 ->
        {[%{word_id: word_id, text: hd(kanji_list).word_text, kanji_info: (Enum.map(kanji_list, & "#{&1.kanji_character}(N#{&1.kanji_level})") |> Enum.join(", "))} | n2to1], n3to1, n3to2}
        
      max_kanji_difficulty == 1 and word_difficulty == 3 ->
        {n2to1, [%{word_id: word_id, text: hd(kanji_list).word_text, kanji_info: (Enum.map(kanji_list, & "#{&1.kanji_character}(N#{&1.kanji_level})") |> Enum.join(", "))} | n3to1], n3to2}
        
      # Contains N2 kanji (but no N1)
      max_kanji_difficulty == 2 and word_difficulty == 3 ->
        {n2to1, n3to1, [%{word_id: word_id, text: hd(kanji_list).word_text, kanji_info: (Enum.map(kanji_list, & "#{&1.kanji_character}(N#{&1.kanji_level})") |> Enum.join(", "))} | n3to2]}
        
      true ->
        {n2to1, n3to1, n3to2}
    end
  end)

IO.puts("Proposed Changes:")
IO.puts("=" |> String.duplicate(60))

if n1_from_n2 != [] do
  IO.puts("\nN2 → N1 (#{length(n1_from_n2)} words):")
  IO.puts("-" |> String.duplicate(60))
  for %{text: text, kanji_info: info} <- Enum.sort_by(n1_from_n2, & &1.text) do
    IO.puts("  #{text} - contains: #{info}")
  end
end

if n1_from_n3 != [] do
  IO.puts("\nN3 → N1 (#{length(n1_from_n3)} words):")
  IO.puts("-" |> String.duplicate(60))
  for %{text: text, kanji_info: info} <- Enum.sort_by(n1_from_n3, & &1.text) do
    IO.puts("  #{text} - contains: #{info}")
  end
end

if n2_from_n3 != [] do
  IO.puts("\nN3 → N2 (#{length(n2_from_n3)} words):")
  IO.puts("-" |> String.duplicate(60))
  for %{text: text, kanji_info: info} <- Enum.sort_by(n2_from_n3, & &1.text) do
    IO.puts("  #{text} - contains: #{info}")
  end
end

IO.puts("\n" <> "=" |> String.duplicate(60))
IO.puts("Summary:")
IO.puts("  N2 → N1: #{length(n1_from_n2)} words")
IO.puts("  N3 → N1: #{length(n1_from_n3)} words")
IO.puts("  N3 → N2: #{length(n2_from_n3)} words")
IO.puts("  Total:   #{length(n1_from_n2) + length(n1_from_n3) + length(n2_from_n3)} words")

# Apply changes
IO.puts("\nApply these changes? (yes/no)")

(case IO.gets("") |> String.trim() |> String.downcase() do
  "yes" ->
    IO.puts("\nApplying changes...")

    # Update N2 -> N1
    n1_from_n2_ids = Enum.map(n1_from_n2, & &1.word_id)
    if n1_from_n2_ids != [] do
      {count, _} = 
        from(w in Word, where: w.id in ^n1_from_n2_ids)
        |> Repo.update_all(set: [difficulty: 1])
      IO.puts("  Updated #{count} words: N2 → N1")
    end

    # Update N3 -> N1
    n1_from_n3_ids = Enum.map(n1_from_n3, & &1.word_id)
    if n1_from_n3_ids != [] do
      {count, _} = 
        from(w in Word, where: w.id in ^n1_from_n3_ids)
        |> Repo.update_all(set: [difficulty: 1])
      IO.puts("  Updated #{count} words: N3 → N1")
    end

    # Update N3 -> N2
    n2_from_n3_ids = Enum.map(n2_from_n3, & &1.word_id)
    if n2_from_n3_ids != [] do
      {count, _} = 
        from(w in Word, where: w.id in ^n2_from_n3_ids)
        |> Repo.update_all(set: [difficulty: 2])
      IO.puts("  Updated #{count} words: N3 → N2")
    end

    IO.puts("\nDone!")

  _ ->
    IO.puts("\nAborted. No changes were made.")
end)

# Helper function
 defp format_kanji_info(kanji_list) do
  Enum.map(kanji_list, & "#{&1.kanji_character}(N#{&1.kanji_level})") |> Enum.join(", ")
 end
