# Script for populating the database with ALL kanji and words
#
#     mix run priv/repo/seeds.exs
#

import Ecto.Query
alias Medoru.Content
alias Medoru.Repo

# Helper to clean kana readings (remove hyphens)
clean_kana = fn reading ->
  if is_binary(reading) do
    reading
    |> String.replace(~r/[-]$/, "")
    |> String.replace(~r/^[-]/, "")
  else
    reading
  end
end

# ========== SEED ALL KANJI ==========
kanji_path = Path.join(__DIR__, "seeds/kanji_all_full.json")

if File.exists?(kanji_path) do
  data = File.read!(kanji_path) |> Jason.decode!()
  kanji_list = data["kanji"] || data

  IO.puts("Seeding #{length(kanji_list)} kanji...")

  Enum.each(kanji_list, fn k ->
    readings =
      Enum.map(k["readings"] || [], fn r ->
        %{
          reading_type: String.to_atom(r["reading_type"]),
          reading: clean_kana.(r["reading"]),
          romaji: r["romaji"],
          usage_notes: Map.get(r, "usage_notes")
        }
      end)

    attrs = %{
      character: k["character"],
      meanings: k["meanings"],
      stroke_count: k["stroke_count"],
      jlpt_level: k["jlpt_level"],
      frequency: k["frequency"],
      radicals: k["radicals"] || [],
      stroke_data: k["stroke_data"] || %{}
    }

    case Content.create_kanji_with_readings(attrs, readings) do
      {:ok, _} -> :ok
      {:error, _} -> IO.puts("  ⚠ #{k["character"]} (exists)")
    end
  end)

  IO.puts("Total kanji: #{Enum.count(Content.list_kanji())}")
  IO.puts("Total readings: #{Enum.count(Content.list_kanji_readings())}")
else
  IO.puts("Warning: #{kanji_path} not found")
end

# ========== SEED ALL WORDS ==========
words_path = Path.join(__DIR__, "seeds/words_all.json")

if File.exists?(words_path) do
  data = File.read!(words_path) |> Jason.decode!()
  words_list = data["words"] || data

  IO.puts("\nSeeding #{length(words_list)} words...")

  # Build kanji lookup map
  kanji_map = Content.list_kanji() |> Map.new(fn k -> {k.character, k} end)

  # Preload readings for each kanji
  kanji_with_readings =
    kanji_map
    |> Map.new(fn {char, kanji} ->
      {char, %{kanji | kanji_readings: Content.list_readings_for_kanji(kanji.id)}}
    end)

  # Map JMdict POS to word_type
  map_word_type = fn pos_list ->
    pos = List.first(pos_list) || ""

    cond do
      String.contains?(pos, "verb") -> :verb
      String.contains?(pos, "adjective (keiyoushi)") -> :adjective
      String.contains?(pos, "adjectival nouns") -> :adjective
      String.contains?(pos, "adverb") -> :adverb
      String.contains?(pos, "counter") -> :counter
      String.contains?(pos, "expressions") -> :expression
      String.contains?(pos, "pronoun") -> :noun
      String.contains?(pos, "noun") -> :noun
      true -> :other
    end
  end

  # Helper to extract kanji from text
  extract_kanji_chars = fn text ->
    text
    |> String.graphemes()
    |> Enum.filter(fn char ->
      code = String.to_charlist(char) |> hd()
      code >= 0x4E00 and code <= 0x9FFF
    end)
  end

  # Calculate word difficulty based on hardest kanji
  # Kana-only words default to N5 (easiest)
  calculate_difficulty = fn text, kanji_map ->
    kanji_chars = extract_kanji_chars.(text)

    if kanji_chars == [] do
      # Kana-only words are N5
      5
    else
      # Get the minimum jlpt_level (hardest) among all kanji
      kanji_chars
      |> Enum.map(fn char ->
        case Map.get(kanji_map, char) do
          # Unknown kanji = assume hardest (N1)
          nil -> 1
          kanji -> kanji.jlpt_level || 1
        end
      end)
      |> Enum.min()
    end
  end

  # Calculate sort score for lesson ordering
  # Primary: frequency (lower = more common)
  # Secondary: visual complexity (kanji count, kana count) 
  calculate_sort_score = fn text, frequency ->
    kanji_chars = extract_kanji_chars.(text)
    kanji_count = length(kanji_chars)
    kana_count = String.length(text) - kanji_count

    # Complexity tier based on visual pattern:
    # (1,0), (1,1), (1,2), (2,0), (2,1), (1,3), (2,2), (3,0), (3,1), ...
    complexity_tier =
      case {kanji_count, kana_count} do
        {1, 0} -> 1
        {1, 1} -> 2
        {1, 2} -> 3
        {2, 0} -> 4
        {2, 1} -> 5
        {1, 3} -> 6
        {2, 2} -> 7
        {3, 0} -> 8
        {3, 1} -> 9
        {1, 4} -> 10
        {2, 3} -> 11
        {3, 2} -> 12
        {4, 0} -> 13
        {4, 1} -> 14
        {k, n} -> k * 10 + n
      end

    # Final score: frequency * 100 + complexity
    # Groups by frequency band first, then complexity within band
    (frequency || 1000) * 100 + complexity_tier
  end

  # Filter valid words and normalize
  valid_words =
    words_list
    |> Enum.filter(fn w ->
      text = w["text"]

      String.length(text) <= 255 and
        String.match?(
          text,
          ~r/[\x{4e00}-\x{9fff}\x{3040}-\x{309f}\x{30a0}-\x{30ff}\x{ff00}-\x{ffef}ー]+/u
        )
    end)
    |> Enum.map(fn w ->
      # Calculate difficulty based on actual kanji in the word
      calculated_difficulty = calculate_difficulty.(w["text"], kanji_map)

      # Calculate sort score for lesson ordering
      sort_score = calculate_sort_score.(w["text"], w["usage_frequency"])

      meaning = w["meaning"]

      truncated_meaning =
        if String.length(meaning) > 250, do: String.slice(meaning, 0, 250) <> "...", else: meaning

      word_type = map_word_type.(w["pos"] || [])

      w
      |> Map.put("difficulty", calculated_difficulty)
      |> Map.put("meaning", truncated_meaning)
      |> Map.put("word_type", word_type)
      |> Map.put("sort_score", sort_score)
    end)

  IO.puts("Filtered to #{length(valid_words)} valid words")

  valid_words
  |> Enum.with_index()
  |> Enum.each(fn {w, idx} ->
    attrs = %{
      text: w["text"],
      meaning: w["meaning"],
      reading: w["reading"],
      difficulty: w["difficulty"],
      usage_frequency: w["usage_frequency"],
      word_type: w["word_type"] || :noun,
      sort_score: w["sort_score"]
    }

    links =
      (w["kanji"] || [])
      |> Enum.map(fn k ->
        case Map.get(kanji_with_readings, k["character"]) do
          nil ->
            nil

          kanji ->
            reading_id =
              if k["reading"] && k["reading"] != "" do
                clean = clean_kana.(k["reading"])

                Enum.find_value(kanji.kanji_readings, nil, fn r ->
                  if r.reading == clean, do: r.id, else: nil
                end)
              else
                nil
              end

            %{position: k["position"], kanji_id: kanji.id, kanji_reading_id: reading_id}
        end
      end)
      |> Enum.reject(&is_nil/1)

    expected = length(w["kanji"] || [])

    if expected == 0 || length(links) == expected do
      case Content.create_word_with_kanji(attrs, links) do
        {:ok, _} ->
          if rem(idx, 500) == 0, do: IO.puts("  ✓ #{idx + 1}/#{length(valid_words)}")

        {:error, _} ->
          if idx < 5, do: IO.puts("  ⚠ #{w["text"]} (error)")
      end
    end
  end)

  IO.puts("Total words: #{Enum.count(Content.list_words())}")
  IO.puts("Total word-kanji links: #{Enum.count(Content.list_word_kanjis())}")
else
  IO.puts("Warning: #{words_path} not found")
end

# ========== SEED BADGES ==========
alias Medoru.Gamification
badges_path = Path.join(__DIR__, "seeds/badges.json")

if File.exists?(badges_path) do
  data = File.read!(badges_path) |> Jason.decode!()
  badges = if is_list(data), do: data, else: data["badges"] || []

  IO.puts("\nSeeding #{length(badges)} badges...")

  Enum.each(badges, fn b ->
    attrs = %{
      name: b["name"],
      description: b["description"],
      icon: b["icon"],
      color: b["color"],
      criteria_type: String.to_atom(b["criteria_type"]),
      criteria_value: b["criteria_value"],
      order_index: b["order_index"]
    }

    case Gamification.create_badge(attrs) do
      {:ok, _} -> :ok
      {:error, _} -> IO.puts("  ⚠ #{b["name"]} (exists)")
    end
  end)

  IO.puts("Total badges: #{Enum.count(Gamification.list_badges())}")
end

IO.puts("\n✅ All seeding complete!")
