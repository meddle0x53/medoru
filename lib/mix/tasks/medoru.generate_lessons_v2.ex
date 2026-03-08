defmodule Mix.Tasks.Medoru.GenerateLessonsV2 do
  @moduledoc """
  Generates system vocabulary lessons with progressive kanji learning.

  This version implements a sophisticated lesson generation algorithm that:
  1. Starts with kana-only words
  2. Groups words by the kanji they introduce
  3. Introduces kanji gradually (1-2 new kanji per lesson)
  4. Reuses learned kanji in subsequent lessons

  ## Examples

      # Generate all system lessons with new algorithm
      mix medoru.generate_lessons_v2

      # Generate for specific level only
      mix medoru.generate_lessons_v2 --level N5

      # Preview what would be created
      mix medoru.generate_lessons_v2 --dry-run

      # Regenerate all lessons
      mix medoru.generate_lessons_v2 --force
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, LessonWord, Word}

  import Ecto.Query

  require Logger

  @shortdoc "Generate system vocabulary lessons with progressive kanji learning"

  @words_per_lesson 4

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          level: :string,
          dry_run: :boolean,
          force: :boolean
        ],
        aliases: [
          l: :level,
          d: :dry_run,
          f: :force
        ]
      )

    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    force = Keyword.get(opts, :force, false)
    level = parse_level(opts[:level])

    if dry_run do
      Mix.shell().info("DRY RUN - No changes will be made")
    end

    if force && !dry_run do
      Mix.shell().info("Clearing existing system lessons...")
      delete_system_lessons(level)
    end

    generate_lessons(level, dry_run)

    unless dry_run do
      show_stats()
    end
  end

  defp parse_level(nil), do: nil

  defp parse_level(level) when is_binary(level) do
    case String.upcase(level) do
      "N5" -> 5
      "N4" -> 4
      "N3" -> 3
      "N2" -> 2
      "N1" -> 1
      _ -> nil
    end
  end

  defp generate_lessons(nil, dry_run) do
    Mix.shell().info("Generating progressive lessons for all JLPT levels...")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      Mix.shell().info("")
      Mix.shell().info("=== JLPT N#{level} ===")
      generate_lessons_for_level(level, dry_run)
    end)
  end

  defp generate_lessons(level, dry_run) do
    Mix.shell().info("Generating progressive lessons for JLPT N#{level}...")
    generate_lessons_for_level(level, dry_run)
  end

  defp generate_lessons_for_level(difficulty, dry_run) do
    # Get all words for this level with their kanji
    words =
      Word
      |> where(difficulty: ^difficulty)
      |> preload(word_kanjis: :kanji)
      |> Repo.all()

    total_words = length(words)

    if total_words == 0 do
      Mix.shell().info("  No words found for N#{difficulty}")
      return()
    end

    Mix.shell().info("  Found #{total_words} words")

    # Build word data with kanji analysis
    word_data =
      Enum.map(words, fn word ->
        kanji_chars =
          word.word_kanjis
          |> Enum.map(& &1.kanji.character)
          |> Enum.filter(& &1)

        %{
          word: word,
          kanji_chars: kanji_chars,
          kanji_count: length(kanji_chars),
          frequency: word.usage_frequency || 1000,
          is_kana_only: kanji_chars == [],
          id: word.id
        }
      end)

    # Separate kana-only and kanji words
    {kana_words, kanji_words} = Enum.split_with(word_data, & &1.is_kana_only)

    # Sort kana words by frequency
    kana_words = Enum.sort_by(kana_words, & &1.frequency)

    # Sort kanji words: single kanji first, then by frequency
    single_kanji = Enum.filter(kanji_words, &(&1.kanji_count == 1))
    multi_kanji = Enum.filter(kanji_words, &(&1.kanji_count >= 2))

    single_kanji = Enum.sort_by(single_kanji, &{hd(&1.kanji_chars), &1.frequency})
    multi_kanji = Enum.sort_by(multi_kanji, &{&1.kanji_count, &1.frequency})

    # Build lessons progressively
    kana_lessons = chunk_into_lessons(kana_words, @words_per_lesson)

    # Group single kanji words by their kanji
    single_kanji_lessons =
      single_kanji
      |> Enum.chunk_by(&hd(&1.kanji_chars))
      |> Enum.flat_map(&chunk_into_lessons(&1, @words_per_lesson))

    # Multi-kanji words - we'll group them later based on learned kanji
    multi_kanji_lessons = chunk_into_lessons(multi_kanji, @words_per_lesson)

    all_lessons = kana_lessons ++ single_kanji_lessons ++ multi_kanji_lessons

    Mix.shell().info("  Creating #{length(all_lessons)} lessons (#{length(kana_lessons)} kana, #{length(single_kanji_lessons)} single-kanji, #{length(multi_kanji_lessons)} multi-kanji)...")

    # Create lessons
    Enum.with_index(all_lessons, 1)
    |> Enum.each(fn {lesson_words, index} ->
      create_lesson(difficulty, index, lesson_words, dry_run)
    end)
  end

  defp chunk_into_lessons(words, size) do
    words
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.take(&1, size))
  end

  defp create_lesson(difficulty, order_index, word_data_list, dry_run) do
    words = Enum.map(word_data_list, & &1.word)

    # Generate title based on content
    title = generate_lesson_title(word_data_list)

    # Build description
    description = generate_lesson_description(words, word_data_list)

    lesson_attrs = %{
      title: title,
      description: description,
      difficulty: difficulty,
      order_index: order_index,
      lesson_type: :reading
    }

    if dry_run do
      # Only show first 20 for dry run
      if order_index <= 20 do
        Mix.shell().info("  [DRY RUN ##{order_index}] #{title}")
        Mix.shell().info("     Words: #{Enum.map(words, & &1.text) |> Enum.join(", ")}")

        # Show kanji info
        kanji_in_lesson =
          word_data_list
          |> Enum.flat_map(& &1.kanji_chars)
          |> Enum.uniq()

        types =
          word_data_list
          |> Enum.map(fn w ->
            if w.is_kana_only, do: "kana", else: "#{w.kanji_count}k"
          end)
          |> Enum.join(", ")

        Mix.shell().info("     Kanji: #{Enum.join(kanji_in_lesson, " ")} | Types: #{types}")
      end
    else
      existing =
        Lesson
        |> where(difficulty: ^difficulty, order_index: ^order_index)
        |> Repo.one()

      if existing do
        Mix.shell().info("  ⚠ Lesson exists: #{title}")
      else
        case Content.create_lesson_with_words(lesson_attrs, build_word_links(words)) do
          {:ok, lesson} ->
            Mix.shell().info("  ✓ Created ##{order_index}: #{lesson.title}")

          {:error, changeset} ->
            Mix.shell().error("  ✗ Failed: #{title}")
            IO.inspect(changeset.errors, label: "Errors")
        end
      end
    end
  end

  defp generate_lesson_title(word_data_list) do
    # Get all kanji in this lesson
    all_kanji =
      word_data_list
      |> Enum.flat_map(& &1.kanji_chars)
      |> Enum.uniq()

    # Check if it's a kana-only lesson
    all_kana = Enum.all?(word_data_list, & &1.is_kana_only)

    cond do
      all_kana ->
        # Use first word as title
        first = hd(word_data_list).word.text
        "#{first} Kana"

      length(all_kanji) == 1 ->
        # Single kanji focus
        "#{hd(all_kanji)} Focus"

      length(all_kanji) == 2 ->
        # Two kanji
        "#{Enum.join(all_kanji, "")} Pair"

      true ->
        # Multiple kanji - use first word
        first_word = hd(word_data_list).word.text
        "#{first_word} Set"
    end
  end

  defp generate_lesson_description(words, word_data_list) do
    word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")

    # Count by type
    kana_count = Enum.count(word_data_list, & &1.is_kana_only)
    one_kanji = Enum.count(word_data_list, &(&1.kanji_count == 1 and not &1.is_kana_only))
    multi_kanji = Enum.count(word_data_list, &(&1.kanji_count >= 2))

    complexity =
      cond do
        kana_count > 0 and one_kanji == 0 and multi_kanji == 0 ->
          "#{kana_count} kana-only"

        kana_count == 0 and one_kanji > 0 and multi_kanji == 0 ->
          "#{one_kanji} single-kanji"

        multi_kanji > 0 ->
          "#{kana_count} kana, #{one_kanji} single, #{multi_kanji} multi-kanji"

        true ->
          "#{kana_count} kana, #{one_kanji} single-kanji"
      end

    "Learn #{length(words)} words (#{complexity}): #{word_texts}"
  end

  defp build_word_links(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, position} ->
      %{
        word_id: word.id,
        position: position
      }
    end)
  end

  defp delete_system_lessons(nil) do
    # Simple approach - delete lessons matching any pattern
    query =
      from(l in Lesson,
        where:
          like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
            like(l.title, "%Set%") or like(l.title, "%Basics%") or like(l.title, "%Words%") or
            like(l.title, "%Vocabulary%")
      )

    Repo.delete_all(query)

    Mix.shell().info("Deleted existing system lessons")
  end

  defp delete_system_lessons(level) do
    query =
      from(l in Lesson,
        where:
          l.difficulty == ^level and
            (like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
               like(l.title, "%Set%") or like(l.title, "%Basics%") or like(l.title, "%Words%") or
               like(l.title, "%Vocabulary%"))
      )

    Repo.delete_all(query)

    Mix.shell().info("Deleted existing N#{level} system lessons")
  end

  defp show_stats do
    total_lessons =
      from(l in Lesson,
        where:
          like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
            like(l.title, "%Set%")
      )
      |> Repo.aggregate(:count, :id)

    by_level =
      from(l in Lesson,
        where:
          like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
            like(l.title, "%Set%")
      )
      |> group_by([l], l.difficulty)
      |> select([l], {l.difficulty, count(l.id)})
      |> Repo.all()
      |> Map.new()

    total_lesson_words =
      from(lw in LessonWord,
        join: l in Lesson,
        on: lw.lesson_id == l.id,
        where:
          like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
            like(l.title, "%Set%")
      )
      |> Repo.aggregate(:count, :id)

    avg_words =
      if total_lessons > 0 do
        Float.round(total_lesson_words / total_lessons, 1)
      else
        0
      end

    Mix.shell().info("")
    Mix.shell().info("=== Progressive Vocabulary Lessons ===")
    Mix.shell().info("Total Lessons: #{total_lessons}")
    Mix.shell().info("Total Word Links: #{total_lesson_words}")
    Mix.shell().info("Avg Words/Lesson: #{avg_words}")
    Mix.shell().info("")
    Mix.shell().info("By JLPT Level:")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      count = Map.get(by_level, level, 0)

      word_count =
        from(lw in LessonWord,
          join: l in Lesson,
          on: lw.lesson_id == l.id,
          where:
            l.difficulty == ^level and
              (like(l.title, "%Kana%") or like(l.title, "%Focus%") or like(l.title, "%Pair%") or
                 like(l.title, "%Set%"))
        )
        |> Repo.aggregate(:count, :id)

      Mix.shell().info("  N#{level}: #{count} lessons (#{word_count} words)")
    end)

    Mix.shell().info("")
    Mix.shell().info("Lessons follow progressive kanji learning:")
    Mix.shell().info("  1. Kana-only words first")
    Mix.shell().info("  2. Single kanji focus (group words by kanji)")
    Mix.shell().info("  3. Multi-kanji words (building on learned kanji)")
  end

  defp return, do: :ok
end
