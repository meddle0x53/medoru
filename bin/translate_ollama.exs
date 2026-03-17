#!/usr/bin/env elixir

# Translate using local Ollama instance
# Requires: Ollama installed with a multilingual model (e.g., llama3, mixtral)

defmodule OllamaTranslator do
  @api_url "http://localhost:11434/api/generate"
  @batch_size 10
  
  def run do
    IO.puts("🦙 N3 Translation via Ollama")
    IO.puts("============================")
    IO.puts("")
    IO.puts("Make sure Ollama is running with a multilingual model:")
    IO.puts("  ollama pull llama3.2")
    IO.puts("  ollama pull mixtral")
    IO.puts("")
    
    process_batches(0)
  end
  
  defp process_batches(processed) do
    words = fetch_batch()
    
    if length(words) == 0 do
      IO.puts("\n✅ Done! Translated #{processed} words")
    else
      IO.write("\r📦 Translating #{processed + length(words)}...")
      
      case translate_batch(words) do
        {:ok, translations} ->
          update_words(words, translations)
          process_batches(processed + length(words))
          
        {:error, reason} ->
          IO.puts("\n❌ Error: #{reason}")
      end
    end
  end
  
  defp fetch_batch do
    sql = """
    SELECT id, text, meaning 
    FROM words 
    WHERE difficulty = 3 AND translations->'bg'->>'meaning' = meaning
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
          [id, text, meaning] = String.split(line, "|")
          %{"id" => id, "text" => text, "meaning" => meaning}
        end)
      _ -> []
    end
  end
  
  defp translate_batch(words) do
    meanings = Enum.map(words, & &1["meaning"])
    
    prompt = """
    Translate these English words/phrases to Bulgarian.
    Return ONLY the Bulgarian translations, one per line, in the same order.
    
    English:
    #{Enum.join(meanings, "\n")}
    
    Bulgarian:
    """
    
    body = Jason.encode!(%{
      model: "llama3.2",  # or "mixtral", "gemma2", etc.
      prompt: prompt,
      stream: false
    })
    
    case Req.post(@api_url, body: body, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: response}} ->
        translations = 
          response["response"]
          |> String.trim()
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
        
        if length(translations) == length(words) do
          {:ok, translations}
        else
          {:error, "Translation count mismatch"}
        end
        
      {:error, reason} ->
        {:error, "Ollama request failed: #{inspect(reason)}"}
    end
  end
  
  defp update_words(words, translations) do
    Enum.zip(words, translations)
    |> Enum.each(fn {word, trans} ->
      escaped = String.replace(trans, "'", "''")
      sql = """
      UPDATE words 
      SET translations = COALESCE(translations, '{}') || '{"bg": {"meaning": "#{escaped}"}}'::jsonb 
      WHERE id = '#{word["id"]}';
      """
      System.cmd("psql", ["-d", "medoru_dev", "-c", sql])
    end)
  end
end

OllamaTranslator.run()
