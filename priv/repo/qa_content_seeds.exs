# =============================================================================
# QA Content Seeds - Minimal data for testing
# =============================================================================
# Loads just N5 kanji and a subset of words for QA testing
# Run with: MIX_ENV=qa mix run priv/repo/qa_content_seeds.exs
# =============================================================================

alias Medoru.Content

IO.puts("""
╔══════════════════════════════════════════════════════════════╗
║           QA Content Seeder (Minimal Data)                    ║
╚══════════════════════════════════════════════════════════════╝
""")

# Helper to clean kana readings
clean_kana = fn reading ->
  if is_binary(reading) do
    reading
    |> String.replace(~r/[-]$/, "")
    |> String.replace(~r/^[-]/, "")
  else
    reading
  end
end

# ========== SEED N5 KANJI ==========
kanji_files = [
  {"N5", "priv/repo/seeds/kanji_n5_full.json"}
]

total_kanji = 0

for {level, path} <- kanji_files do
  if File.exists?(path) do
    data = File.read!(path) |> Jason.decode!()
    kanji_list = data["kanji"] || data

    IO.puts("🈯 Seeding #{length(kanji_list)} #{level} kanji...")

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
        {:ok, _} -> 
          total_kanji = total_kanji + 1
        {:error, _} -> 
          :ok  # Already exists
      end
    end)
  else
    IO.puts("⚠️  #{path} not found")
  end
end

IO.puts("✅ Total kanji: #{Enum.count(Content.list_kanji())}")
IO.puts("✅ Total readings: #{Enum.count(Content.list_kanji_readings())}")

# ========== SEED WORDS (First 1000 only for speed) ==========
words_path = "priv/repo/seeds/words.json"

if File.exists?(words_path) do
  words_list = File.read!(words_path) |> Jason.decode!()
  
  # Take first 1000 words for QA speed
  words_subset = Enum.take(words_list, 1000)

  IO.puts("\n📚 Seeding #{length(words_subset)} words (subset for QA)...")

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
      code = String.to_charlist(char) |> List.first()
      code && code >= 0x4E00 && code <= 0x9FFF
    end)
  end

  # Helper to find reading for kanji in word context
  find_kanji_reading = fn kanji_char, _word_text, word_reading ->
    kanji = Map.get(kanji_with_readings, kanji_char)

    if kanji do
      # Try to match reading from word
      readings = kanji.kanji_readings || []

      # Find reading that appears in the word reading
      matched_reading =
        Enum.find(readings, fn r ->
          reading_kana = r.reading
          String.contains?(word_reading, reading_kana)
        end)

      # Default to first reading if no match
      matched_reading || List.first(readings)
    end
  end

  Enum.with_index(words_subset, 1)
  |> Enum.each(fn {w, idx} ->
    text = w["text"]
    reading = w["reading"]

    # Extract kanji from word
    kanji_chars = extract_kanji_chars.(text)

    # Build word_kanjis associations
    word_kanjis =
      kanji_chars
      |> Enum.with_index()
      |> Enum.map(fn {char, position} ->
        kanji = Map.get(kanji_map, char)

        if kanji do
          reading_match = find_kanji_reading.(char, text, reading)

          %{
            kanji_id: kanji.id,
            position: position,
            kanji_reading_id: if(reading_match, do: reading_match.id, else: nil)
          }
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Map word type
    word_type = map_word_type.(w["parts_of_speech"] || [])

    meanings = w["meanings"] || [w["meaning"] || ""]
    
    attrs = %{
      text: text,
      reading: reading,
      meaning: List.first(meanings) || "",
      meanings: meanings,
      word_type: word_type,
      difficulty: w["difficulty"] || 5,
      usage_frequency: w["usage_frequency"] || 0,
      common: w["common"] || false,
      word_kanjis: word_kanjis
    }

    case Content.create_word(attrs) do
      {:ok, _} ->
        if rem(idx, 100) == 0 do
          IO.write(".")
        end

      {:error, _} ->
        :ok  # Already exists
    end
  end)

  IO.puts("")
  IO.puts("✅ Total words: #{Enum.count(Content.list_words())}")
else
  IO.puts("⚠️  #{words_path} not found")
end

# ========== SEED LESSONS ==========
IO.puts("\n📖 Creating sample lessons...")

lessons = [
  %{title: "N5 Basics 1", description: "Basic N5 vocabulary", level: 5, order: 1},
  %{title: "N5 Basics 2", description: "More N5 vocabulary", level: 5, order: 2},
  %{title: "N5 Verbs", description: "Common N5 verbs", level: 5, order: 3}
]

Enum.each(lessons, fn lesson_attrs ->
  case Content.create_lesson(lesson_attrs) do
    {:ok, _} -> IO.puts("  ✅ #{lesson_attrs.title}")
    {:error, _} -> IO.puts("  ⚠️  #{lesson_attrs.title} (exists)")
  end
end)

IO.puts("""

✅ QA content seeding complete!

📊 Summary:
   • Kanji: #{Enum.count(Content.list_kanji())}
   • Readings: #{Enum.count(Content.list_kanji_readings())}
   • Words: #{Enum.count(Content.list_words())}
   • Lessons: #{Enum.count(Content.list_lessons())}

🚀 Ready for testing!
""")
