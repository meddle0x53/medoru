# Script to import Core 6000 Anki deck data
#
# This script supports multiple formats:
# 1. Simple TSV: core_rank | word | reading | meaning
# 2. Anki Export: guid | word | furigana | meaning | example | tags
# 3. Core 6000 Optimized format with various field arrangements
#
# Usage:
#   mix run priv/repo/core6000_importer.exs path/to/export.txt [--format anki|tsv|auto]

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.Word

defmodule Core6000Importer do
  @moduledoc """
  Imports Core 6000 vocabulary data from various formats.
  """

  @doc """
  Import from file with auto-detected or specified format.
  """
  def import_from_file(path, format \\ :auto) do
    IO.puts("Importing Core 6000 data from #{path}...")

    if not File.exists?(path) do
      IO.puts("❌ Error: File not found: #{path}")
      show_help()
      exit({:shutdown, 1})
    end

    # Detect format if auto
    format = if format == :auto, do: detect_format(path), else: format
    IO.puts("Detected format: #{format}")

    # Parse file
    entries = parse_file(path, format)

    if entries == [] do
      IO.puts("❌ No valid entries found in file")
      show_help()
      exit({:shutdown, 1})
    end

    IO.puts("Parsed #{length(entries)} Core 6000 entries")

    # Build lookup map by word text
    lookup_map =
      entries
      |> Enum.group_by(&normalize_word(&1.word))
      |> Map.new(fn {word, items} -> {word, items} end)

    IO.puts("Unique words: #{map_size(lookup_map)}")

    # Update words in database
    {matched, updated, examples_added} =
      Word
      |> Repo.all()
      |> Enum.reduce({0, 0, 0}, fn word, {matched, updated, examples} ->
        case Map.get(lookup_map, normalize_word(word.text)) do
          nil ->
            {matched, updated, examples}

          entries ->
            # Find best matching entry by reading
            best_match = find_best_match(entries, word.reading)

            # Build update attrs
            attrs = %{
              core_rank: best_match.core_rank,
              # Add example sentence if available
              example_sentence: best_match[:example] || word[:example_sentence],
              example_reading: best_match[:example_reading] || word[:example_reading],
              example_meaning: best_match[:example_meaning] || word[:example_meaning]
            }
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()

            # Update word
            word
            |> Ecto.Changeset.change(attrs)
            |> Repo.update!()

            example_count = if best_match[:example], do: 1, else: 0
            {matched + 1, updated + 1, examples + example_count}
        end
      end)

    IO.puts("")
    IO.puts("✅ Import complete!")
    IO.puts("  Words matched: #{matched}")
    IO.puts("  Words updated: #{updated}")
    IO.puts("  Examples added: #{examples_added}")
    IO.puts("  Words not in Core 6000: #{Repo.aggregate(Word, :count, :id) - updated}")

    show_core_distribution()
  end

  @doc """
  Detect file format based on content.
  """
  def detect_format(path) do
    first_lines =
      path
      |> File.stream!()
      |> Enum.take(5)
      |> Enum.join("\n")

    cond do
      # Anki export has guid (alphanumeric id) in first field
      String.match?(first_lines, ~r/^[a-zA-Z0-9!@#]{10,}\t/) ->
        :anki

      # Core 6000 Optimized has specific tags
      String.contains?(first_lines, "Core-Index") or
      String.contains?(first_lines, "Optimized-Voc-Index") ->
        :optimized

      # Simple TSV with numeric rank in first column
      String.match?(first_lines, ~r/^\d+\t/) ->
        :tsv

      # CSV format
      String.match?(first_lines, ~r/^\d+,/) ->
        :csv

      true ->
        :tsv
    end
  end

  @doc """
  Parse file based on format.
  """
  def parse_file(path, format) do
    lines =
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.reject(&(&1 == ""))

    case format do
      :anki -> parse_anki_lines(lines)
      :optimized -> parse_optimized_lines(lines)
      :tsv -> parse_tsv_lines(lines)
      :csv -> parse_csv_lines(lines)
      _ -> parse_tsv_lines(lines)
    end
  end

  # Parse Anki export format
  # Fields: guid, word, furigana/kana, meaning, example sentence, tags
  defp parse_anki_lines(lines) do
    lines
    |> Enum.map(fn line ->
      fields = String.split(line, "\t", trim: true)

      case fields do
        [guid, word, furigana, meaning, example | rest] when length(fields) >= 5 ->
          # Try to extract core rank from tags (last field)
          tags = List.last(rest) || ""
          core_rank = extract_core_rank_from_tags(tags) || extract_rank_from_meaning(meaning)

          # Clean HTML from fields
          word_clean = strip_html(word)
          reading_clean = strip_html(furigana)
          meaning_clean = strip_html(meaning)
          example_clean = strip_html(example)

          # Try to parse example sentence components
          {example_reading, example_meaning} = parse_example_sentence(example_clean)

          if core_rank do
            %{
              core_rank: core_rank,
              word: word_clean,
              reading: reading_clean,
              meaning: meaning_clean,
              example: example_clean,
              example_reading: example_reading,
              example_meaning: example_meaning,
              tags: tags
            }
          else
            nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse Core 6000 Optimized format
  # Has fields like: Vocabulary-Kanji, Vocabulary-Furigana, Vocabulary-Kana, etc.
  defp parse_optimized_lines(lines) do
    # Check if first line is header
    lines =
      if String.contains?(hd(lines), "Vocabulary-Kanji") do
        tl(lines)
      else
        lines
      end

    lines
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} ->
      fields = String.split(line, "\t", trim: true)

      # Optimized format has many fields, try to extract key ones
      case fields do
        [kanji | rest] when length(fields) >= 8 ->
          # Fields vary by deck, try common patterns
          # Look for fields containing reading and meaning
          readings = Enum.filter(rest, &kana?/1)
          meanings = Enum.filter(rest, &english?/1)

          word = if kanji != "", do: kanji, else: List.first(readings, "")
          reading = List.first(readings, "")
          meaning = List.first(meanings, "Unknown")

          # Try to find Core-Index in tags (usually last field)
          core_rank =
            case List.last(rest) do
              nil -> idx
              tags -> extract_core_rank_from_tags(tags) || idx
            end

          %{
            core_rank: core_rank,
            word: word,
            reading: reading,
            meaning: meaning
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse simple TSV: core_rank | word | reading | meaning | [example] | [sentence_meaning]
  defp parse_tsv_lines(lines) do
    lines
    |> Enum.map(fn line ->
      fields = String.split(line, "\t")

      case fields do
        [rank, word, reading, meaning | rest] ->
          case Integer.parse(rank) do
            {core_rank, _} ->
              entry = %{
                core_rank: core_rank,
                word: String.trim(word),
                reading: String.trim(reading),
                meaning: String.trim(meaning)
              }

              # Add example if available
              case rest do
                [example, ex_reading, ex_meaning | _] ->
                  entry
                  |> Map.put(:example, String.trim(example))
                  |> Map.put(:example_reading, String.trim(ex_reading))
                  |> Map.put(:example_meaning, String.trim(ex_meaning))

                [example | _] ->
                  Map.put(entry, :example, String.trim(example))

                _ ->
                  entry
              end

            :error ->
              nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse CSV format
  defp parse_csv_lines(lines) do
    lines
    |> Enum.map(fn line ->
      # Simple CSV parsing (doesn't handle quoted commas)
      fields = String.split(line, ",")

      case fields do
        [rank, word, reading, meaning | _rest] ->
          case Integer.parse(rank) do
            {core_rank, _} ->
              %{
                core_rank: core_rank,
                word: String.trim(word) |> String.replace("\"", ""),
                reading: String.trim(reading) |> String.replace("\"", ""),
                meaning: String.trim(meaning) |> String.replace("\"", "")
              }

            :error ->
              nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Helper: Strip HTML tags
  defp strip_html(text) do
    text
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Helper: Extract core rank from Anki tags
  defp extract_core_rank_from_tags(tags) do
    # Look for patterns like "core_500", "core500", "Core 500", "5001"
    cond do
      Regex.match?(~r/core[_\s]?(\d+)/i, tags) ->
        [_, rank] = Regex.run(~r/core[_\s]?(\d+)/i, tags)
        String.to_integer(rank)

      Regex.match?(~r/^(\d{1,4})\s*$/i, tags) ->
        [_, rank] = Regex.run(~r/^(\d{1,4})\s*$/i, tags)
        String.to_integer(rank)

      true ->
        nil
    end
  end

  # Helper: Try to extract rank from meaning field (sometimes contains "(1)" etc.)
  defp extract_rank_from_meaning(meaning) do
    if Regex.match?(~r/^\s*\(\d+\)/, meaning) do
      [_, rank] = Regex.run(~r/^\s*\((\d+)\)/, meaning)
      String.to_integer(rank)
    else
      nil
    end
  end

  # Helper: Parse example sentence to extract reading and meaning
  defp parse_example_sentence(example) do
    # Common format: Japanese sentence (reading) - English meaning
    # Or: Japanese sentence | reading | meaning
    cond do
      Regex.match?(~r/^(.*?)\s*\((.*?)\)\s*[-–—]\s*(.+)$/, example) ->
        [_, _sentence, reading, meaning] =
          Regex.run(~r/^(.*?)\s*\((.*?)\)\s*[-–—]\s*(.+)$/, example)

        {reading, meaning}

      true ->
        {nil, nil}
    end
  end

  # Helper: Check if text is kana
  defp kana?(text) do
    String.match?(text, ~r/[ぁ-んァ-ンー]+/)
  end

  # Helper: Check if text is English
  defp english?(text) do
    String.match?(text, ~r/^[a-zA-Z\s,.'"!?()-]+$/)
  end

  # Normalize word for matching
  defp normalize_word(word) do
    word
    |> String.trim()
    |> String.downcase()
    |> strip_html()
  end

  # Find best match by reading
  defp find_best_match(entries, word_reading) do
    word_reading = strip_html(word_reading)

    # Prefer exact reading match
    case Enum.find(entries, &(strip_html(&1.reading) == word_reading)) do
      nil -> List.first(entries)
      match -> match
    end
  end

  # Show core distribution
  defp show_core_distribution do
    IO.puts("")
    IO.puts("Core 6000 Distribution in Database:")

    distribution =
      from(w in Word,
        where: not is_nil(w.core_rank),
        group_by:
          fragment(
            "CASE 
          WHEN core_rank <= 1000 THEN 'Core 1-1000 (N5)'
          WHEN core_rank <= 2000 THEN 'Core 1001-2000 (N4)'
          WHEN core_rank <= 3000 THEN 'Core 2001-3000 (N3)'
          WHEN core_rank <= 5000 THEN 'Core 3001-5000 (N2)'
          ELSE 'Core 5001-6000 (N1)'
        END"
          ),
        select: {
          fragment(
            "CASE 
            WHEN core_rank <= 1000 THEN 'Core 1-1000 (N5)'
            WHEN core_rank <= 2000 THEN 'Core 1001-2000 (N4)'
            WHEN core_rank <= 3000 THEN 'Core 2001-3000 (N3)'
            WHEN core_rank <= 5000 THEN 'Core 3001-5000 (N2)'
            ELSE 'Core 5001-6000 (N1)'
          END"
          ),
          count(w.id)
        },
        order_by: fragment("MIN(core_rank)")
      )
      |> Repo.all()

    Enum.each(distribution, fn {range, count} ->
      IO.puts("  #{range}: #{count} words")
    end)

    total_core = from(w in Word, where: not is_nil(w.core_rank), select: count(w.id)) |> Repo.one()
    IO.puts("  Total with Core rank: #{total_core}")
  end

  defp show_help do
    IO.puts("")
    IO.puts("Usage:")
    IO.puts("  mix run priv/repo/core6000_importer.exs path/to/file.txt [--format anki|tsv|csv|auto]")
    IO.puts("")
    IO.puts("Supported formats:")
    IO.puts("  anki      - Anki export (tab-separated with guid)")
    IO.puts("  tsv       - Simple TSV (rank word reading meaning)")
    IO.puts("  csv       - CSV format")
    IO.puts("  optimized - Core 6000 Optimized deck format")
    IO.puts("  auto      - Auto-detect format (default)")
    IO.puts("")
    IO.puts("Download Core 6000 from:")
    IO.puts("  - AnkiWeb: https://ankiweb.net/shared/info/1863168610")
    IO.puts("  - Then: File → Export → 'Notes in Plain Text'")
  end
end

# Main execution
args = System.argv()

{path, format} =
  case args do
    [path] -> {path, :auto}
    [path, "--format", fmt] -> {path, String.to_atom(fmt)}
    ["--format", fmt, path] -> {path, String.to_atom(fmt)}
    _ ->
      Core6000Importer.show_help()
      exit({:shutdown, 1})
  end

Core6000Importer.import_from_file(path, format)
