# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

import Ecto.Query
alias Medoru.Content
alias Medoru.Repo

# Load N5 Kanji from JSON
n5_kanji_path = Path.join(__DIR__, "seeds/kanji_n5.json")

if File.exists?(n5_kanji_path) do
  n5_kanji =
    n5_kanji_path
    |> File.read!()
    |> Jason.decode!()

  IO.puts("Seeding #{length(n5_kanji)} N5 kanji...")

  Enum.each(n5_kanji, fn kanji_data ->
    readings_attrs = kanji_data["readings"]

    kanji_attrs = %{
      character: kanji_data["character"],
      meanings: kanji_data["meanings"],
      stroke_count: kanji_data["stroke_count"],
      jlpt_level: kanji_data["jlpt_level"],
      frequency: kanji_data["frequency"],
      radicals: kanji_data["radicals"],
      stroke_data: %{}
    }

    # Convert reading data to atom keys
    readings_attrs =
      Enum.map(readings_attrs, fn reading ->
        %{
          reading_type: String.to_atom(reading["reading_type"]),
          reading: reading["reading"],
          romaji: reading["romaji"],
          usage_notes: Map.get(reading, "usage_notes")
        }
      end)

    case Content.create_kanji_with_readings(kanji_attrs, readings_attrs) do
      {:ok, _kanji} ->
        IO.puts("  ✓ Created kanji: #{kanji_data["character"]}")

      {:error, changeset} ->
        IO.puts("  ✗ Failed to create kanji: #{kanji_data["character"]}")
        IO.inspect(changeset.errors, label: "Errors")
    end
  end)

  IO.puts("\nKanji seeding complete!")
  IO.puts("Total kanji: #{Enum.count(Content.list_kanji())}")
  IO.puts("Total readings: #{Enum.count(Content.list_kanji_readings())}")
else
  IO.puts("Warning: #{n5_kanji_path} not found. Skipping kanji seeds.")
end

# Load N5 Words from JSON
n5_words_path = Path.join(__DIR__, "seeds/words_n5.json")

if File.exists?(n5_words_path) do
  n5_words =
    n5_words_path
    |> File.read!()
    |> Jason.decode!()

  IO.puts("\nSeeding #{length(n5_words)} N5 words...")

  # Build a lookup map of kanji character to kanji record with readings
  kanji_map =
    Content.list_kanji()
    |> Repo.preload(:kanji_readings)
    |> Map.new(fn kanji -> {kanji.character, kanji} end)

  Enum.each(n5_words, fn word_data ->
    word_attrs = %{
      text: word_data["text"],
      meaning: word_data["meaning"],
      reading: word_data["reading"],
      difficulty: word_data["difficulty"],
      usage_frequency: word_data["usage_frequency"],
      word_type: String.to_atom(Map.get(word_data, "word_type", "other"))
    }

    # Build kanji links for this word
    kanji_links =
      Enum.map(word_data["kanji"], fn kanji_data ->
        character = kanji_data["character"]
        position = kanji_data["position"]
        reading_text = kanji_data["reading"]

        case Map.get(kanji_map, character) do
          nil ->
            IO.puts("  ⚠ Kanji not found: #{character}")
            nil

          kanji ->
            # Find the reading that matches
            reading_id =
              if reading_text != "" do
                Enum.find_value(kanji.kanji_readings, nil, fn reading ->
                  if reading.reading == reading_text, do: reading.id, else: nil
                end)
              else
                nil
              end

            %{
              position: position,
              kanji_id: kanji.id,
              kanji_reading_id: reading_id
            }
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Only create if we found all kanji
    if length(kanji_links) == length(word_data["kanji"]) do
      case Content.create_word_with_kanji(word_attrs, kanji_links) do
        {:ok, _word} ->
          IO.puts("  ✓ Created word: #{word_data["text"]}")

        {:error, changeset} ->
          IO.puts("  ✗ Failed to create word: #{word_data["text"]}")
          IO.inspect(changeset.errors, label: "Errors")
      end
    else
      IO.puts("  ⚠ Skipped word (missing kanji): #{word_data["text"]}")
    end
  end)

  IO.puts("\nWord seeding complete!")
  IO.puts("Total words: #{Enum.count(Content.list_words())}")
  IO.puts("Total word-kanji links: #{Enum.count(Content.list_word_kanjis())}")
else
  IO.puts("Warning: #{n5_words_path} not found. Skipping word seeds.")
end

# Load N5 Lessons from JSON
n5_lessons_path = Path.join(__DIR__, "seeds/lessons_n5.json")

if File.exists?(n5_lessons_path) do
  n5_lessons =
    n5_lessons_path
    |> File.read!()
    |> Jason.decode!()

  IO.puts("\nSeeding #{length(n5_lessons)} N5 lessons...")

  # Build a lookup map of word text to word record
  word_map =
    Content.list_words()
    |> Map.new(fn word -> {word.text, word} end)

  Enum.each(n5_lessons, fn lesson_data ->
    lesson_attrs = %{
      title: lesson_data["title"],
      description: lesson_data["description"],
      difficulty: lesson_data["difficulty"],
      order_index: lesson_data["order_index"],
      lesson_type: String.to_atom(lesson_data["lesson_type"] || "reading")
    }

    # Build word links for this lesson
    word_links =
      lesson_data["words"]
      |> Enum.with_index()
      |> Enum.map(fn {text, position} ->
        case Map.get(word_map, text) do
          nil ->
            IO.puts("  ⚠ Word not found: #{text}")
            nil

          word ->
            %{
              position: position,
              word_id: word.id
            }
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Only create if we found all words
    if length(word_links) == length(lesson_data["words"]) do
      case Content.create_lesson_with_words(lesson_attrs, word_links) do
        {:ok, _lesson} ->
          IO.puts("  ✓ Created lesson: #{lesson_data["title"]}")

        {:error, changeset} ->
          IO.puts("  ✗ Failed to create lesson: #{lesson_data["title"]}")
          IO.inspect(changeset.errors, label: "Errors")
      end
    else
      IO.puts("  ⚠ Skipped lesson (missing words): #{lesson_data["title"]}")
    end
  end)

  IO.puts("\nLesson seeding complete!")
  IO.puts("Total lessons: #{Enum.count(Content.list_lessons())}")
  IO.puts("Total lesson-word links: #{Enum.count(Content.list_lesson_words())}")
else
  IO.puts("Warning: #{n5_lessons_path} not found. Skipping lesson seeds.")
end

IO.puts("\n✅ All seeding complete!")
