#!/usr/bin/env elixir

# Bulk translation using Google Cloud Translation API
# Requires: GOOGLE_API_KEY environment variable

defmodule GoogleTranslator do
  @api_url "https://translation.googleapis.com/language/translate/v2"
  @batch_size 100  # Google allows up to 128 texts per request
  
  def run do
    api_key = System.get_env("GOOGLE_API_KEY")
    
    unless api_key do
      IO.puts("❌ Set GOOGLE_API_KEY environment variable")
      System.halt(1)
    end
    
    IO.puts("🌐 Starting Google Translate bulk translation")
    IO.puts("============================================")
    
    # Process in batches
    process_batches(api_key, 0)
  end
  
  defp process_batches(api_key, processed_count) do
    # Fetch batch of words with English placeholders
    words = fetch_batch()
    
    if length(words) == 0 do
      IO.puts("\n✅ All done! Translated #{processed_count} words")
      :ok
    else
      IO.write("\r📦 Translating batch... (#{processed_count} done)")
      
      # Extract English meanings
      texts = Enum.map(words, & &1["meaning"])
      
      # Call Google Translate API
      case translate_batch(texts, api_key) do
        {:ok, translations} ->
          # Update database with Bulgarian translations
          update_words(words, translations)
          process_batches(api_key, processed_count + length(words))
          
        {:error, reason} ->
          IO.puts("\n❌ Error: #{reason}")
          System.halt(1)
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
        
      _ ->
        []
    end
  end
  
  defp translate_batch(texts, api_key) do
    headers = [
      {"Content-Type", "application/json"}
    ]
    
    body = Jason.encode!(%{
      q: texts,
      source: "en",
      target: "bg",
      format: "text"
    })
    
    url = "#{@api_url}?key=#{api_key}"
    
    case Req.post(url, headers: headers, body: body, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: response}} ->
        translations = get_in(response, ["data", "translations"])
        |> Enum.map(& &1["translatedText"])
        {:ok, translations}
        
      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}
        
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
  
  defp update_words(words, translations) do
    Enum.zip(words, translations)
    |> Enum.each(fn {word, translation} ->
      # Escape single quotes
      escaped = String.replace(translation, "'", "''")
      
      sql = """
      UPDATE words 
      SET translations = COALESCE(translations, '{}') || '{"bg": {"meaning": "#{escaped}"}}'::jsonb 
      WHERE id = '#{word["id"]}';
      """
      
      System.cmd("psql", ["-d", "medoru_dev", "-c", sql])
    end)
  end
end

# Run
GoogleTranslator.run()
