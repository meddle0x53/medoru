# Script to update word_types based on POS data in words table
# 
#     mix run priv/repo/update_word_types.exs

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.Word

IO.puts("Updating word_types...")

# Map function for word_type
map_word_type = fn pos_list ->
  pos = List.first(pos_list) || ""
  cond do
    String.contains?(pos, "verb") -> "verb"
    String.contains?(pos, "adjective (keiyoushi)") -> "adjective"
    String.contains?(pos, "adjectival nouns") -> "adjective"
    String.contains?(pos, "adverb") -> "adverb"
    String.contains?(pos, "counter") -> "counter"
    String.contains?(pos, "expressions") -> "expression"
    String.contains?(pos, "pronoun") -> "noun"
    String.contains?(pos, "noun") -> "noun"
    true -> "other"
  end
end

words_path = Path.join(__DIR__, "seeds/words_all.json")

if File.exists?(words_path) do
  data = File.read!(words_path) |> Jason.decode!()
  words_list = data["words"] || []
  
  IO.puts("Loaded #{length(words_list)} words from JSON")
  
  # Process in batches
  {updated, errors} = 
    words_list
    |> Enum.chunk_every(5000)
    |> Enum.reduce({0, 0}, fn batch, {updated, errors} ->
      # Build case statement for batch update
      cases = 
        batch
        |> Enum.map(fn w ->
          word_type = map_word_type.(w["pos"] || [])
          text = w["text"] |> String.replace("'", "''")
          "WHEN '#{text}' THEN '#{word_type}'"
        end)
        |> Enum.join(" ")
      
      texts = Enum.map_join(batch, ",", fn w -> 
        "'" <> String.replace(w["text"], "'", "''") <> "'"
      end)
      
      sql = """
      UPDATE words 
      SET word_type = CASE text 
        #{cases}
        ELSE word_type 
      END
      WHERE text IN (#{texts})
      """
      
      try do
        Repo.query!(sql)
        {updated + length(batch), errors}
      rescue
        e -> 
          IO.puts("Error in batch: #{Exception.message(e)}")
          {updated, errors + length(batch)}
      end
    end)
  
  IO.puts("✅ Done! Updated ~#{updated} words, #{errors} errors")
  
  # Show distribution
  counts = 
    from(w in Word, group_by: w.word_type, select: {w.word_type, count(w.id)})
    |> Repo.all()
  
  IO.puts("\nWord type distribution:")
  Enum.each(counts, fn {type, count} ->
    IO.puts("  #{type}: #{count}")
  end)
else
  IO.puts("Error: #{words_path} not found")
end
