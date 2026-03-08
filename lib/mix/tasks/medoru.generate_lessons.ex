defmodule Mix.Tasks.Medoru.GenerateLessons do
  @moduledoc """
  Generates system vocabulary lessons from existing words in the database.

  Lessons are automatically created by grouping words by JLPT level (N5-N1),
  ordered by frequency (most common first), with 3-5 words per lesson.

  ## Examples

      # Generate all system lessons
      mix medoru.generate_lessons

      # Generate lessons for specific level only
      mix medoru.generate_lessons --level N5

      # Preview what would be created (dry run)
      mix medoru.generate_lessons --dry-run

      # Regenerate all lessons (delete existing system lessons first)
      mix medoru.generate_lessons --force

  ## Lesson Structure

  - Each lesson contains 3-5 words
  - Lesson title is the first word (e.g., "日本語 Lesson")
  - Words are ordered by frequency (most common first)
  - Difficulty matches JLPT level (5=N5, 4=N4, etc.)
  - System lessons are accessible to all users

  ## Test Integration

  Future iterations will add tests at the end of each lesson.
  For now, lessons are created with words ready for testing.
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, LessonWord, Word}

  import Ecto.Query

  require Logger

  @shortdoc "Generate system vocabulary lessons from existing words"

  @words_per_lesson_min 3
  @words_per_lesson_max 5

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

    # Start the application
    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    force = Keyword.get(opts, :force, false)
    level = parse_level(opts[:level])

    if dry_run do
      Mix.shell().info("DRY RUN - No changes will be made")
    end

    # Optionally clear existing system lessons
    if force && !dry_run do
      Mix.shell().info("Clearing existing system lessons...")
      delete_system_lessons(level)
    end

    # Generate lessons
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
    # Generate for all levels N5 to N1
    Mix.shell().info("Generating system lessons for all JLPT levels...")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      Mix.shell().info("")
      Mix.shell().info("=== JLPT N#{level} ===")
      generate_lessons_for_level(level, dry_run)
    end)
  end

  defp generate_lessons(level, dry_run) do
    Mix.shell().info("Generating system lessons for JLPT N#{level}...")
    generate_lessons_for_level(level, dry_run)
  end

  defp generate_lessons_for_level(level, dry_run) do
    # Get words for this difficulty level, ordered by frequency
    words =
      Word
      |> where(difficulty: ^level)
      |> order_by([w], asc: w.usage_frequency)
      |> Repo.all()

    total_words = length(words)

    if total_words == 0 do
      Mix.shell().info("  No words found for N#{level}")
      return()
    end

    Mix.shell().info("  Found #{total_words} words")

    # Group words into lessons (3-5 words each)
    lessons = chunk_words_into_lessons(words)

    Mix.shell().info("  Creating #{length(lessons)} lessons...")

    Enum.with_index(lessons, 1)
    |> Enum.each(fn {lesson_words, index} ->
      create_lesson(level, index, lesson_words, dry_run)
    end)
  end

  defp chunk_words_into_lessons(words) do
    # Split words into chunks of 3-5 words per lesson
    # Using 4 as the target for balanced lessons
    Enum.chunk_every(words, 4)
    |> Enum.map(fn chunk ->
      # Ensure minimum 3 words by merging small final chunk
      chunk
    end)
    |> merge_small_chunks()
  end

  defp merge_small_chunks(chunks) do
    # If the last chunk has fewer than 3 words, merge with previous
    case List.pop_at(chunks, -1) do
      {nil, _} ->
        chunks

      {last_chunk, rest} when length(last_chunk) < @words_per_lesson_min and length(rest) > 0 ->
        # Merge last chunk with previous
        {prev_chunk, rest_without_prev} = List.pop_at(rest, -1)
        merged = prev_chunk ++ last_chunk

        if length(merged) > @words_per_lesson_max do
          # If merged is too big, keep separate with just the last words
          rest ++ [last_chunk]
        else
          rest_without_prev ++ [merged]
        end

      _ ->
        chunks
    end
  end

  defp create_lesson(difficulty, order_index, words, dry_run) do
    # Pick a clean lesson title from the words
    title = generate_lesson_title(words)

    # Build description with word list
    word_list_text = Enum.map(words, & &1.text) |> Enum.join(", ")

    lesson_attrs = %{
      title: title,
      description: "Learn #{length(words)} common Japanese vocabulary words: #{word_list_text}.",
      difficulty: difficulty,
      order_index: order_index,
      lesson_type: :reading
    }

    if dry_run do
      Mix.shell().info("  [DRY RUN] #{title}")
      Mix.shell().info("    Words: #{word_list_text}")
    else
      # Check if lesson already exists at this difficulty/order
      existing =
        Lesson
        |> where(difficulty: ^difficulty, order_index: ^order_index)
        |> Repo.one()

      if existing do
        Mix.shell().info("  ⚠ Lesson exists: #{lesson_attrs.title} (order: #{order_index})")
      else
        case Content.create_lesson_with_words(lesson_attrs, build_word_links(words)) do
          {:ok, lesson} ->
            Mix.shell().info("  ✓ Created: #{lesson.title} (#{length(words)} words)")

          {:error, changeset} ->
            Mix.shell().error("  ✗ Failed: #{lesson_attrs.title}")
            IO.inspect(changeset.errors, label: "Errors")
        end
      end
    end
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

  # Generate a clean lesson title from the first suitable word
  defp generate_lesson_title(words) do
    words
    |> Enum.find_value(fn word ->
      text = word.text

      # Prefer words that:
      # 1. Are 2-4 characters long
      # 2. Don't start with particles (お, ご, は, が, etc.)
      # 3. Contain actual kanji
      cond do
        String.length(text) < 2 ->
          nil

        String.length(text) > 6 ->
          nil

        starts_with_particle?(text) ->
          nil

        contains_kanji?(text) ->
          "#{text} Vocabulary"

        true ->
          nil
      end
    end)
    |> case do
      nil ->
        # Fallback to first word with kanji or just first word
        first = List.first(words)

        if contains_kanji?(first.text) do
          "#{first.text} Vocabulary"
        else
          "Vocabulary Set #{first.id |> String.slice(0, 4)}"
        end

      title ->
        title
    end
  end

  defp starts_with_particle?(text) do
    particles = [
      "お",
      "ご",
      "は",
      "が",
      "を",
      "に",
      "で",
      "と",
      "の",
      "も",
      "や",
      "へ",
      "から",
      "より",
      "その",
      "この",
      "あの",
      "どの"
    ]

    Enum.any?(particles, &String.starts_with?(text, &1))
  end

  defp contains_kanji?(text) do
    text
    |> String.to_charlist()
    |> Enum.any?(fn cp ->
      (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF)
    end)
  end

  defp delete_system_lessons(nil) do
    # Delete all system lessons (we'll identify them by pattern or all reading lessons)
    # For safety, only delete lessons that look auto-generated
    from(l in Lesson, where: like(l.title, "%Lesson%"))
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing system lessons")
  end

  defp delete_system_lessons(level) do
    from(l in Lesson, where: l.difficulty == ^level and like(l.title, "%Lesson%"))
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing N#{level} system lessons")
  end

  defp show_stats do
    # Count only system-generated lessons (reading type with "Vocabulary" in title)
    total_lessons =
      Lesson
      |> where([l], l.lesson_type == :reading and like(l.title, "%Vocabulary%"))
      |> Repo.aggregate(:count, :id)

    by_level =
      Lesson
      |> where([l], l.lesson_type == :reading and like(l.title, "%Vocabulary%"))
      |> group_by([l], l.difficulty)
      |> select([l], {l.difficulty, count(l.id)})
      |> Repo.all()
      |> Map.new()

    # Count words in system lessons
    total_lesson_words =
      from(lw in LessonWord,
        join: l in Lesson,
        on: lw.lesson_id == l.id,
        where: l.lesson_type == :reading and like(l.title, "%Vocabulary%")
      )
      |> Repo.aggregate(:count, :id)

    avg_words_per_lesson =
      if total_lessons > 0 do
        Float.round(total_lesson_words / total_lessons, 1)
      else
        0
      end

    Mix.shell().info("")
    Mix.shell().info("=== System Vocabulary Lessons ===")
    Mix.shell().info("Total Lessons: #{total_lessons}")
    Mix.shell().info("Total Word Links: #{total_lesson_words}")
    Mix.shell().info("Avg Words/Lesson: #{avg_words_per_lesson}")
    Mix.shell().info("")
    Mix.shell().info("By JLPT Level:")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      count = Map.get(by_level, level, 0)

      word_count =
        from(lw in LessonWord,
          join: l in Lesson,
          on: lw.lesson_id == l.id,
          where:
            l.difficulty == ^level and l.lesson_type == :reading and like(l.title, "%Vocabulary%")
        )
        |> Repo.aggregate(:count, :id)

      Mix.shell().info("  N#{level}: #{count} lessons (#{word_count} words)")
    end)

    Mix.shell().info("")
    Mix.shell().info("Students can access these lessons from the Lessons page.")
    Mix.shell().info("Future: Tests will be added at the end of each lesson.")
  end

  defp return, do: :ok
end
