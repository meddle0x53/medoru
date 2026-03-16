#!/usr/bin/env elixir

# Interactive N4 Translation - Uses Kimi (this AI) as the translation engine
# Workflow:
# 1. Query DB for 50 untranslated N4 words
# 2. Display English meanings to Kimi
# 3. Kimi translates and provides SQL updates
# 4. Execute SQL to update DB
# 5. Repeat

defmodule InteractiveTranslator do
  @batch_size 50
  
  def run do
    IO.puts("🌙 Interactive N4 Translator")
    IO.puts("============================")
    IO.puts("")
    IO.puts("This script will:")
    IO.puts("1. Fetch #{@batch_size} untranslated N4 words from DB")
    IO.puts("2. Show you the English meanings")
    IO.puts("3. You (Kimi) translate them")
    IO.puts("4. Script updates DB automatically")
    IO.puts("")
    
    # Check what we have
    count_result = System.cmd("psql", ["-d", "medoru_dev", "-t", "-c", 
      "SELECT COUNT(*) FROM words WHERE jlpt_level = 4 AND (translations IS NULL OR translations->>'bg' IS NULL)"])
    
    remaining = 
      case count_result do
        {output, 0} -> 
          output |> String.trim() |> String.to_integer()
        _ -> 
          IO.puts("❌ Could not connect to database")
          System.halt(1)
      end
    
    IO.puts("📊 Remaining N4 words to translate: #{remaining}")
    IO.puts("")
    
    if remaining == 0 do
      IO.puts("✅ All N4 words are already translated!")
      System.halt(0)
    end
    
    batches = div(remaining + @batch_size - 1, @batch_size)
    IO.puts("🚀 This will take ~#{batches} batches")
    IO.puts("")
    
    # Process batches
    process_batches(1, batches)
  end
  
  defp process_batches(current, total) when current > total do
    IO.puts("")
    IO.puts("🎉 All batches complete!")
  end
  
  defp process_batches(current, total) do
    IO.puts("📦 Batch #{current}/#{total}")
    IO.puts(String.duplicate("-", 50))
    
    # Fetch words
    words = fetch_batch()
    
    if length(words) == 0 do
      IO.puts("No more words to translate!")
      :ok
    else
      # Display for translation
      IO.puts("")
      IO.puts("ENGLISH MEANINGS TO TRANSLATE:")
      IO.puts("Please translate these to Bulgarian (pipe-separated format):")
      IO.puts("")
      
      Enum.with_index(words, 1)
      |> Enum.each(fn {word, idx} ->
        IO.puts("#{idx}. #{word["meaning"]}")
      end)
      
      IO.puts("")
      IO.puts("FORMAT: translation1 | translation2 | translation3 | ...")
      IO.puts("Waiting for translations...")
      IO.puts("")
      
      # The user (Kimi) will provide translations
      # This is where the interaction happens
      :done
    end
  end
  
  defp fetch_batch do
    sql = """
    SELECT id, text, meaning, reading 
    FROM words 
    WHERE jlpt_level = 4 AND (translations IS NULL OR translations->>'bg' IS NULL)
    ORDER BY text
    LIMIT #{@batch_size}
    """
    
    case System.cmd("psql", ["-d", "medoru_dev", "-t", "-A", "-F", "|", "-c", sql]) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn line ->
          [id, text, meaning, reading] = String.split(line, "|")
          %{"id" => id, "text" => text, "meaning" => meaning, "reading" => reading}
        end)
        
      _ ->
        IO.puts("❌ Failed to fetch from database")
        []
    end
  end
  
  def apply_translations(words, translations) when is_list(translations) and length(translations) == length(words) do
    sql_parts = 
      Enum.zip(words, translations)
      |> Enum.map(fn {word, translation} ->
        ~s(UPDATE words SET translations = COALESCE(translations, '{}') || '{"bg": {"meaning": "#{escape_string(translation)}"}}'::jsonb WHERE id = '#{word["id"]}';)
      end)
    
    sql = Enum.join(sql_parts, "\n")
    
    IO.puts("Applying #{length(words)} translations...")
    
    case System.cmd("psql", ["-d", "medoru_dev", "-c", sql]) do
      {_, 0} -> 
        IO.puts("✅ Batch #{current_batch()} updated successfully")
        :ok
      {error, _} -> 
        IO.puts("❌ Error: #{error}")
        :error
    end
  end
  
  defp escape_string(str) do
    str
    |> String.replace("'", "''")
    |> String.replace("\\", "\\\\")
  end
  
  defp current_batch do
    case System.cmd("psql", ["-d", "medoru_dev", "-t", "-c", 
      "SELECT COUNT(*) FROM words WHERE jlpt_level = 4 AND translations->>'bg' IS NOT NULL"]) do
      {output, 0} -> 
        translated = output |> String.trim() |> String.to_integer()
        div(translated, @batch_size) + 1
      _ -> 1
    end
  end
end

# Run
InteractiveTranslator.run()
