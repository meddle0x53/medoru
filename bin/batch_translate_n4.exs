#!/usr/bin/env elixir

# N4 Words Batch Translation Script
# Translates 6,808 N4 words in batches of 50 using pipe-separated format
# Usage: mix run bin/batch_translate_n4.exs

require Logger

defmodule BatchTranslator do
  # Configuration
  @batch_size 50
  @api_url "https://api.kimi.com/coding/v1/chat/completions"
  @model "kimi-for-coding"
  
  defp api_key do
    System.get_env("KIMI_CODE_API_KEY") || System.get_env("KIMI_API_KEY")
  end
  
  # Paths
  @progress_file "data/export/words_n4_progress.json"
  @output_file "data/export/words_n4_bg.json"
  @input_file "data/export/words_n4.json"
  
  def run do
    unless api_key() do
      IO.puts("❌ Error: Set KIMI_CODE_API_KEY environment variable")
      System.halt(1)
    end

    IO.puts("🌙 N4 Words Batch Translator")
    IO.puts("============================")
    
    # Load words
    words = load_json(@input_file)
    total = length(words)
    IO.puts("📚 Total words to translate: #{total}")
    
    # Load progress
    {start_index, completed_ids} = load_progress()
    IO.puts("🔄 Resuming from index: #{start_index}")
    IO.puts("✅ Already completed: #{map_size(completed_ids)} words")
    
    # Filter out already translated words
    words_to_translate = 
      if start_index > 0 or map_size(completed_ids) > 0 do
        words
        |> Enum.with_index()
        |> Enum.filter(fn {word, idx} -> 
          idx >= start_index and not Map.has_key?(completed_ids, word["id"])
        end)
        |> Enum.map(fn {word, _idx} -> word end)
      else
        words
      end
    
    remaining = length(words_to_translate)
    IO.puts("📝 Remaining to translate: #{remaining}")
    IO.puts("")
    
    if remaining == 0 do
      IO.puts("✅ All words already translated!")
      generate_final_output(words, completed_ids)
      System.halt(0)
    end
    
    # Process in batches
    batches = Enum.chunk_every(words_to_translate, @batch_size)
    total_batches = length(batches)
    
    IO.puts("🚀 Starting translation of #{total_batches} batches...")
    IO.puts("")
    
    process_batches(batches, completed_ids, total_batches, 1)
    
    # Generate final output
    IO.puts("")
    IO.puts("🎉 Translation complete! Generating final output...")
    generate_final_output(words, completed_ids)
    
    IO.puts("✅ Done! Output saved to: #{@output_file}")
  end
  
  defp process_batches([], completed_ids, _total, _current), do: completed_ids
  
  defp process_batches([batch | rest], completed_ids, total_batches, current_batch) do
    batch_start_time = System.monotonic_time(:millisecond)
    
    IO.write("📦 Batch #{current_batch}/#{total_batches} (#{length(batch)} words)... ")
    
    case translate_batch(batch) do
      {:ok, translations} ->
        updated_ids = 
          Enum.zip(batch, translations)
          |> Enum.reduce(completed_ids, fn {word, translation}, acc ->
            Map.put(acc, word["id"], %{
              "bg" => %{"meaning" => translation}
            })
          end)
        
        save_progress(current_batch * @batch_size, updated_ids)
        
        batch_elapsed = System.monotonic_time(:millisecond) - batch_start_time
        IO.puts("✅ #{batch_elapsed}ms")
        
        Process.sleep(500)
        
        process_batches(rest, updated_ids, total_batches, current_batch + 1)
        
      {:error, reason} ->
        IO.puts("❌ Failed: #{reason}")
        IO.puts("💾 Progress saved. Restart to continue from batch #{current_batch}")
        save_progress((current_batch - 1) * @batch_size, completed_ids)
        System.halt(1)
    end
  end
  
  defp translate_batch(words) do
    meanings = Enum.map(words, & &1["meaning"])
    prompt = build_prompt(meanings)
    
    case call_translation_api(prompt, length(meanings)) do
      {:ok, response} ->
        translations = parse_response(response, length(meanings))
        
        if length(translations) == length(meanings) do
          {:ok, translations}
        else
          {:error, "Translation count mismatch: expected #{length(meanings)}, got #{length(translations)}"}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp build_prompt(meanings) do
    meanings_text = Enum.join(meanings, " | ")
    
    """
    Translate these English words/phrases to Bulgarian. 
    Return ONLY the Bulgarian translations in the same format: word1 | word2 | word3 | ...
    Keep translations concise (1-3 words max). Use common Bulgarian words.
    
    English: #{meanings_text}
    
    Bulgarian:
    """
  end
  
  defp call_translation_api(prompt, expected_count) do
    body = Jason.encode!(%{
      model: @model,
      messages: [
        %{role: "system", content: "You are a precise English to Bulgarian translator. Always respond with pipe-separated translations matching the input count exactly."},
        %{role: "user", content: prompt}
      ],
      temperature: 0.3,
      max_tokens: expected_count * 20
    })
    
    case Req.post(@api_url,
      headers: [
        {"Authorization", "Bearer #{api_key()}"},
        {"Content-Type", "application/json"}
      ],
      body: body,
      receive_timeout: 60_000
    ) do
      {:ok, %{status: 200, body: response}} ->
        content = get_in(response, ["choices", Access.at(0), "message", "content"])
        {:ok, content}
        
      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}
        
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
  
  defp parse_response(response, expected_count) do
    response
    |> String.trim()
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn text ->
      text
      |> String.replace(~r/^\d+[.\)]\s*/, "")
      |> String.trim()
    end)
    |> Enum.reject(&(&1 == ""))
    |> pad_or_trim(expected_count)
  end
  
  defp pad_or_trim(translations, expected_count) do
    cond do
      length(translations) == expected_count ->
        translations
        
      length(translations) < expected_count ->
        padding = List.duplicate("[translation missing]", expected_count - length(translations))
        translations ++ padding
        
      true ->
        Enum.take(translations, expected_count)
    end
  end
  
  defp load_progress do
    if File.exists?(@progress_file) do
      case File.read(@progress_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"index" => index, "translations" => translations}} ->
              {index, translations}
            _ ->
              {0, %{}}
          end
        _ ->
          {0, %{}}
      end
    else
      {0, %{}}
    end
  end
  
  defp save_progress(index, translations) do
    progress = %{
      "index" => index,
      "translations" => translations,
      "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    File.write!(@progress_file, Jason.encode!(progress))
  end
  
  defp generate_final_output(words, translations_map) do
    translated_words = 
      Enum.map(words, fn word ->
        case Map.get(translations_map, word["id"]) do
          nil -> word
          translation -> put_in(word, ["translations"], translation)
        end
      end)
    
    File.write!(@output_file, Jason.encode!(translated_words))
    
    translated_count = Enum.count(translated_words, & &1["translations"])
    IO.puts("📊 Total translated: #{translated_count}/#{length(words)}")
  end
  
  defp load_json(path) do
    File.read!(path) |> Jason.decode!()
  end
end

# Run the translator
BatchTranslator.run()
