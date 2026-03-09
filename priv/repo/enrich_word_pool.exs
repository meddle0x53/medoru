#!/usr/bin/env elixir
# Enrich word pool with database IDs and word types
# Supplement with additional words from database to reach target counts
# 
# Usage: mix run priv/repo/enrich_word_pool.exs

defmodule EnrichWordPool do
  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Content.Word

  # Target word counts per level for 100 lessons each
  # 15-20 words per lesson = 1500-2000 words per level
  @targets %{
    "n5" => 1500,
    "n4" => 1800,
    "n3" => 2500
  }

  # Difficulty mapping: 5=N5, 4=N4, 3=N3
  @difficulty_map %{
    "n5" => 5,
    "n4" => 4,
    "n3" => 3
  }

  def enrich do
    IO.puts("Loading word pool...")
    json = File.read!("data/v7_word_pool.json")
    data = Jason.decode!(json)

    levels = ["n5", "n4", "n3"]
    
    enriched = Enum.reduce(levels, %{}, fn level, acc ->
      core_words = data["words_by_level"][level]
      target = @targets[level]
      difficulty = @difficulty_map[level]
      
      IO.puts("")
      IO.puts("=== #{String.upcase(level)} ===")
      IO.puts("Core 6000 words: #{length(core_words)}")
      IO.puts("Target: #{target} words")
      
      # Enrich core words
      enriched_core = 
        core_words
        |> Enum.map(&enrich_word/1)
        |> Enum.reject(&is_nil/1)
      
      matched_count = length(enriched_core)
      IO.puts("Matched to DB: #{matched_count}")
      
      # If we need more words, supplement from database
      final_words = if matched_count < target do
        needed = target - matched_count
        IO.puts("Supplementing with #{needed} words from database...")
        
        # Get word IDs we already have
        existing_ids = Enum.map(enriched_core, & &1["word_id"])
        
        # Query additional words from database
        supplements = get_supplemental_words(difficulty, needed, existing_ids)
        IO.puts("Found #{length(supplements)} supplemental words")
        
        enriched_core ++ supplements
      else
        enriched_core
      end
      
      IO.puts("Final #{level} count: #{length(final_words)}")
      Map.put(acc, level, final_words)
    end)

    # Calculate stats
    total_after = Enum.sum(Enum.map(levels, &length(enriched[&1])))
    
    IO.puts("")
    IO.puts("=" |> String.duplicate(40))
    IO.puts("Enrichment Complete!")
    IO.puts("  N5: #{length(enriched["n5"])} / #{@targets["n5"]} words")
    IO.puts("  N4: #{length(enriched["n4"])} / #{@targets["n4"]} words")
    IO.puts("  N3: #{length(enriched["n3"])} / #{@targets["n3"]} words")
    IO.puts("  Total: #{total_after} words")

    # Write enriched pool
    output = %{
      "meta" => %{
        "source" => "anki2.txt + database supplement",
        "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "targets" => @targets,
        "total_words" => total_after
      },
      "words_by_level" => enriched
    }

    File.write!("data/v7_lesson_pool.json", Jason.encode!(output, pretty: true))
    IO.puts("")
    IO.puts("✅ Enriched pool written to data/v7_lesson_pool.json")

    # Show samples
    IO.puts("")
    IO.puts("Sample N5 words (showing DB-supplemented):")
    enriched["n5"] |> Enum.drop(400) |> Enum.take(3) |> Enum.each(&IO.inspect/1)
  end

  defp enrich_word(%{"word" => word_text, "reading" => reading} = entry) do
    # Try to find matching word in database
    query = from w in Word,
      where: w.text == ^word_text,
      limit: 1

    db_word = Repo.one(query)

    case db_word do
      nil ->
        # Try kana-only match if word has no kanji
        if String.match?(word_text, ~r/^[\p{Hiragana}\p{Katakana}]+$/u) do
          query = from w in Word,
            where: w.reading == ^word_text,
            limit: 1
          
          case Repo.one(query) do
            nil -> nil
            found -> build_enriched_entry(entry, found)
          end
        else
          nil
        end

      word ->
        build_enriched_entry(entry, word)
    end
  end

  defp enrich_word(_), do: nil

  defp build_enriched_entry(entry, db_word) do
    Map.merge(entry, %{
      "word_id" => db_word.id,
      "db_meaning" => db_word.meaning,
      "word_type" => db_word.word_type,
      "difficulty" => db_word.difficulty,
      "core_rank" => db_word.core_rank,
      "db_reading" => db_word.reading
    })
  end

  defp get_supplemental_words(difficulty, needed, exclude_ids) do
    query = from w in Word,
      where: w.difficulty == ^difficulty,
      where: w.id not in ^exclude_ids,
      where: not is_nil(w.word_type),
      order_by: [asc: w.core_rank, desc: w.usage_frequency],
      limit: ^needed,
      select: %{
        word_id: w.id,
        word: w.text,
        reading: w.reading,
        db_reading: w.reading,
        db_meaning: w.meaning,
        meaning: w.meaning,
        word_type: w.word_type,
        difficulty: w.difficulty,
        core_rank: w.core_rank,
        has_kanji: fragment("? ~ '[\\u4e00-\\u9faf]'", w.text),
        kanji_count: 0,
        example_japanese: nil,
        example_reading: nil,
        example_english: nil
      }

    Repo.all(query)
    |> Enum.map(fn w ->
      %{
        "word_id" => w.word_id,
        "word" => w.word,
        "reading" => w.reading,
        "db_reading" => w.db_reading,
        "db_meaning" => w.db_meaning,
        "meaning" => w.meaning,
        "word_type" => w.word_type,
        "difficulty" => w.difficulty,
        "core_rank" => w.core_rank,
        "has_kanji" => w.has_kanji,
        "kanji_count" => (if w.has_kanji, do: count_kanji(w.word), else: 0),
        "example_japanese" => w.example_japanese,
        "example_reading" => w.example_reading,
        "example_english" => w.example_english
      }
    end)
  end

  defp count_kanji(text) do
    text
    |> String.graphemes()
    |> Enum.count(fn char ->
      code = String.to_charlist(char) |> hd()
      code >= 0x4E00 and code <= 0x9FFF
    end)
  rescue
    _ -> 0
  end
end

EnrichWordPool.enrich()
