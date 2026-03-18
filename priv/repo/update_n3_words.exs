# Script to update N3 words to N2 or N1 based on their kanji levels
# - If word contains ANY N1 kanji → N1
# - If word contains ANY N2 kanji → N2
# Run with: mix run priv/repo/update_n3_words.exs

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.Word

IO.puts("Starting N3 word update based on kanji levels...")
IO.puts("Rules: ANY N1 kanji → N1, ANY N2 kanji → N2")

# Get all N3 words with their kanji
n3_words =
  Word
  |> where([w], w.difficulty == 3)
  |> preload(word_kanjis: :kanji)
  |> Repo.all()

IO.puts("Found #{length(n3_words)} N3 words to process")

{to_n1, to_n2, unchanged} =
  n3_words
  |> Enum.reduce({[], [], []}, fn word, {n1_acc, n2_acc, unchanged_acc} ->
    kanji_list = Enum.map(word.word_kanjis, & &1.kanji) |> Enum.reject(&is_nil/1)
    
    if kanji_list == [] do
      # No kanji associated, keep as N3
      {n1_acc, n2_acc, [word | unchanged_acc]}
    else
      kanji_levels = Enum.map(kanji_list, & &1.jlpt_level)
      
      cond do
        # ANY kanji is N1 → N1
        Enum.any?(kanji_levels, & &1 == 1) ->
          {[word | n1_acc], n2_acc, unchanged_acc}
          
        # ANY kanji is N2 → N2
        Enum.any?(kanji_levels, & &1 == 2) ->
          {n1_acc, [word | n2_acc], unchanged_acc}
          
        # No N1 or N2 kanji, keep as N3
        true ->
          {n1_acc, n2_acc, [word | unchanged_acc]}
      end
    end
  end)

IO.puts("Words to update to N1: #{length(to_n1)}")
IO.puts("Words to update to N2: #{length(to_n2)}")
IO.puts("Words staying N3: #{length(unchanged)}")

# Update words to N1 first (higher priority)
if to_n1 != [] do
  n1_ids = Enum.map(to_n1, & &1.id)
  
  {n1_count, _} =
    Word
    |> where([w], w.id in ^n1_ids)
    |> Repo.update_all(set: [difficulty: 1])
  
  IO.puts("\nUpdated #{n1_count} words to N1")
  
  # Show examples
  IO.puts("\nSample N1 updates (contain ANY N1 kanji):")
  to_n1 |> Enum.take(10) |> Enum.each(fn w ->
    kanji_info = Enum.map(w.word_kanjis, fn wk -> 
      "#{wk.kanji.character}(N#{wk.kanji.jlpt_level})"
    end) |> Enum.join(", ")
    IO.puts("  #{w.text} [#{kanji_info}]")
  end)
end

# Update words to N2
if to_n2 != [] do
  n2_ids = Enum.map(to_n2, & &1.id)
  
  {n2_count, _} =
    Word
    |> where([w], w.id in ^n2_ids)
    |> Repo.update_all(set: [difficulty: 2])
  
  IO.puts("\nUpdated #{n2_count} words to N2")
  
  # Show examples
  IO.puts("\nSample N2 updates (contain ANY N2 kanji, no N1):")
  to_n2 |> Enum.take(10) |> Enum.each(fn w ->
    kanji_info = Enum.map(w.word_kanjis, fn wk -> 
      "#{wk.kanji.character}(N#{wk.kanji.jlpt_level})"
    end) |> Enum.join(", ")
    IO.puts("  #{w.text} [#{kanji_info}]")
  end)
end

IO.puts("\nDone!")
