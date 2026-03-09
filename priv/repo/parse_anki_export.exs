#!/usr/bin/env elixir
# Parser for Anki export (anki2.txt) to structured JSON
# 
# Usage: mix run priv/repo/parse_anki_export.exs data/anki2.txt --output data/v7_word_pool.json

defmodule AnkiParser do
  @moduledoc """
  Parses Anki export format and extracts structured vocabulary data.
  
  Format per line: Tag\tWord Reading  Reading Meaning  ExJP  ExReading  ExEnglish
  (where  \t = tab,   = double space separator)
  """

  def parse_file(input_path, output_path \\ "data/v7_word_pool.json") do
    IO.puts("Parsing #{input_path}...")

    entries =
      input_path
      |> File.stream!([:utf8])
      |> Stream.reject(&String.starts_with?(&1, "#"))
      |> Stream.reject(&(&1 == "\n"))
      |> Stream.map(&parse_line/1)
      |> Stream.reject(&is_nil/1)
      |> Stream.reject(&reject_note_cards/1)
      |> Enum.to_list()

    IO.puts("Parsed #{length(entries)} valid entries")

    # Categorize by apparent level based on complexity
    categorized = categorize_by_level(entries)

    # Build word pool structure
    word_pool = %{
      meta: %{
        source: "anki2.txt",
        total_entries: length(entries),
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      words_by_level: %{
        n5: Map.get(categorized, :n5, []),
        n4: Map.get(categorized, :n4, []),
        n3: Map.get(categorized, :n3, [])
      },
      all_words: entries
    }

    # Write JSON
    json = Jason.encode!(word_pool, pretty: true)
    File.write!(output_path, json)

    IO.puts("")
    IO.puts("✅ Parsed successfully!")
    IO.puts("  N5 candidates: #{length(word_pool.words_by_level.n5)}")
    IO.puts("  N4 candidates: #{length(word_pool.words_by_level.n4)}")
    IO.puts("  N3 candidates: #{length(word_pool.words_by_level.n3)}")
    IO.puts("  Output: #{output_path}")

    # Show samples by level
    IO.puts("")
    IO.puts("Sample N5 entries:")
    Enum.take(word_pool.words_by_level.n5, 3) |> Enum.each(&IO.inspect/1)
    
    IO.puts("")
    IO.puts("Sample N4 entries:")
    Enum.take(word_pool.words_by_level.n4, 3) |> Enum.each(&IO.inspect/1)
    
    IO.puts("")
    IO.puts("Sample N3 entries:")
    Enum.take(word_pool.words_by_level.n3, 3) |> Enum.each(&IO.inspect/1)
  end

  # Reject note/help cards
  defp reject_note_cards(%{word: word, meaning: meaning}) do
    String.contains?(meaning, "http") ||
    String.contains?(meaning, "NOTE:") ||
    word == "NOTE" ||
    String.length(word) > 50
  end

  defp parse_line(line) do
    # Split by tab
    fields = String.split(line, "\t", trim: true)

    case fields do
      [_tag, combined] ->
        # Parse the combined field
        # Format: "Word Reading  Reading Meaning  ExJP  ExReading  ExEnglish"
        parse_combined_field(combined)

      _ ->
        nil
    end
  end

  defp parse_combined_field(text) do
    # Split by double+ spaces to separate sections
    # Format: Word Reading  Reading Meaning  ExJP  ExReading  ExEnglish
    parts = String.split(text, ~r/\s{2,}/, trim: true)
    
    case parts do
      [word_section, meaning_section, ex_jp, ex_reading, ex_english | _] ->
        parse_word_entry(word_section, meaning_section, ex_jp, ex_reading, ex_english)
        
      # Some entries might be missing the last field
      [word_section, meaning_section, ex_jp, ex_reading] ->
        parse_word_entry(word_section, meaning_section, ex_jp, ex_reading, nil)
        
      # Or even simpler format
      [word_section, meaning_section, ex_jp] ->
        parse_word_entry(word_section, meaning_section, ex_jp, nil, nil)
        
      _ ->
        nil
    end
  end

  defp parse_word_entry(word_section, meaning_section, ex_jp, ex_reading, ex_english) do
    # Word section: "一つ ひとつ ひとつ" or just "それ それ それ"
    word_parts = String.split(word_section, ~r/\s+/, trim: true)
    
    case word_parts do
      [word, reading | _] ->
        # Meaning section might have extra spaces
        meaning = meaning_section |> String.trim()
        
        %{
          word: String.trim(word),
          reading: String.trim(reading),
          meaning: meaning,
          example_japanese: String.trim(ex_jp),
          example_reading: ex_reading && String.trim(ex_reading),
          example_english: ex_english && String.trim(ex_english),
          kanji_count: count_kanji(word),
          has_kanji: has_kanji?(word)
        }

      _ ->
        nil
    end
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

  defp has_kanji?(text) do
    count_kanji(text) > 0
  end

  # Categorize words into approximate JLPT levels
  defp categorize_by_level(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce(%{n5: [], n4: [], n3: []}, fn {entry, index}, acc ->
      level = determine_level(entry, index)
      Map.update!(acc, level, &[entry | &1])
    end)
    |> Map.new(fn {k, v} -> {k, Enum.reverse(v)} end)
  end

  defp determine_level(_entry, index) do
    cond do
      index <= 500 -> :n5
      index <= 1500 -> :n4
      true -> :n3
    end
  end
end

# Main execution
args = System.argv()

{input, output} =
  case args do
    [input] -> {input, "data/v7_word_pool.json"}
    [input, "--output", output] -> {input, output}
    ["--output", output, input] -> {input, output}
    _ ->
      IO.puts("Usage: mix run priv/repo/parse_anki_export.exs input.txt [--output out.json]")
      exit({:shutdown, 1})
  end

AnkiParser.parse_file(input, output)
