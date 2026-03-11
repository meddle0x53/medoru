defmodule Mix.Tasks.Medoru.GenerateLessonsV6 do
  @moduledoc """
  Generates system vocabulary lessons using Core 6000 frequency data.

  Key improvements over v5:
  1. Uses Core 6000 frequency rank for ordering (1 = most common)
  2. Better JLPT level mapping based on Core data
  3. Lessons progress from most common to less common words
  4. Each lesson maintains balanced word types and gradual complexity

  Core 6000 to JLPT mapping:
  - Core 1-1000    → N5 (most essential)
  - Core 1001-2000 → N4
  - Core 2001-3000 → N3
  - Core 3001-5000 → N2
  - Core 5001-6000 → N1 (advanced)

  ## Examples

      mix medoru.generate_lessons_v6              # Generate all levels
      mix medoru.generate_lessons_v6 --level N5   # N5 only
      mix medoru.generate_lessons_v6 --dry-run    # Preview
      mix medoru.generate_lessons_v6 --force      # Regenerate
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, Word, Kanji}

  import Ecto.Query

  require Logger

  @shortdoc "Generate lessons using Core 6000 frequency data"

  @words_per_lesson 4

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [level: :string, dry_run: :boolean, force: :boolean],
        aliases: [l: :level, d: :dry_run, f: :force]
      )

    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    force = Keyword.get(opts, :force, false)
    level = parse_level(opts[:level])

    # Check if we have Core 6000 data
    core_count =
      from(w in Word, where: not is_nil(w.core_rank), select: count(w.id)) |> Repo.one()

    if core_count == 0 do
      Mix.shell().error("No Core 6000 data found!")
      Mix.shell().info("Please import Core 6000 data first:")
      Mix.shell().info("  mix run priv/repo/core6000_importer.exs path/to/core6000.tsv")
      Mix.shell().info("")
      Mix.shell().info("Download from: https://core6000.neocities.org/")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Core 6000 words in database: #{core_count}")

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
    Mix.shell().info("Generating lessons for all JLPT levels...")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      Mix.shell().info("")
      Mix.shell().info("=== JLPT N#{level} ===")
      generate_lessons_for_level(level, dry_run)
    end)
  end

  defp generate_lessons(level, dry_run) do
    Mix.shell().info("Generating lessons for JLPT N#{level}...")
    generate_lessons_for_level(level, dry_run)
  end

  defp generate_lessons_for_level(difficulty, dry_run) do
    # Get kanji for this JLPT level
    allowed_kanji_chars =
      Kanji
      |> where([k], k.jlpt_level >= ^difficulty)
      |> select([k], {k.character, k.jlpt_level})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("  Allowed kanji: #{map_size(allowed_kanji_chars)}")

    # Get words for this level based on Core rank
    {core_min, core_max} = core_range_for_jlpt(difficulty)

    words =
      Word
      |> where([w], not is_nil(w.core_rank))
      |> where([w], w.core_rank >= ^core_min and w.core_rank <= ^core_max)
      |> where([w], w.difficulty >= ^difficulty)
      |> preload(word_kanjis: :kanji)
      |> order_by([w], asc: w.core_rank)
      |> Repo.all()

    Mix.shell().info("  Core #{core_min}-#{core_max} words: #{length(words)}")

    # Filter to only words with allowed kanji
    filtered_words =
      Enum.filter(words, fn word ->
        word_kanjis = get_word_kanji(word)

        if word_kanjis == [] do
          true
        else
          Enum.all?(word_kanjis, fn char -> Map.has_key?(allowed_kanji_chars, char) end)
        end
      end)

    filtered_count = length(words) - length(filtered_words)
    Mix.shell().info("  Valid words: #{length(filtered_words)} (removed #{filtered_count})")

    if filtered_words == [] do
      Mix.shell().info("  No valid words for N#{difficulty}")
    else
      # Build lessons with Core-based ordering
      lessons = build_core_lessons(filtered_words, difficulty)

      Mix.shell().info("  Creating #{length(lessons)} lessons...")

      Enum.with_index(lessons, 1)
      |> Enum.each(fn {lesson_words, index} ->
        create_lesson(difficulty, index, lesson_words, dry_run)
      end)
    end
  end

  defp core_range_for_jlpt(5), do: {1, 1000}
  defp core_range_for_jlpt(4), do: {1001, 2000}
  defp core_range_for_jlpt(3), do: {2001, 3000}
  defp core_range_for_jlpt(2), do: {3001, 5000}
  defp core_range_for_jlpt(1), do: {5001, 6000}

  defp build_core_lessons(words, _difficulty) do
    # Enrich word data
    word_data = enrich_word_data(words)

    # Group by priority kanji (numbers first, then frequency)
    {by_priority_kanji, remaining} = group_by_priority_kanji(word_data)

    # Build lessons in priority order
    kanji_lessons =
      Enum.flat_map(by_priority_kanji, fn {_kanji, words_for_kanji} ->
        # Sort by Core rank (already sorted, but ensure it)
        sorted = Enum.sort_by(words_for_kanji, & &1.core_rank)
        build_balanced_kanji_lessons(sorted)
      end)

    # Add remaining words as mixed lessons
    if remaining != [] do
      mixed_lessons = build_mixed_lessons(remaining)
      kanji_lessons ++ mixed_lessons
    else
      kanji_lessons
    end
  end

  defp enrich_word_data(words) do
    Enum.map(words, fn word ->
      kanji_chars = get_word_kanji(word)
      word_length = String.length(word.text)
      kanji_count = length(kanji_chars)

      %{
        word: word,
        kanji_chars: kanji_chars,
        kanji_count: kanji_count,
        word_length: word_length,
        word_type: word.word_type,
        core_rank: word.core_rank,
        sort_score: word.sort_score || 999_999
      }
    end)
  end

  defp group_by_priority_kanji(word_data) do
    # Priority: number kanji first, then by frequency
    priority_kanji = [
      "一",
      "二",
      "三",
      "四",
      "五",
      "六",
      "七",
      "八",
      "九",
      "十",
      "百",
      "千",
      "万",
      "日",
      "月",
      "年",
      "時",
      "分",
      "人",
      "本"
    ]

    priority_map = Map.new(priority_kanji, fn k -> {k, []} end)

    {by_kanji, remaining} =
      Enum.reduce(word_data, {priority_map, []}, fn wd, {acc, rem} ->
        found = Enum.find(priority_kanji, fn k -> k in wd.kanji_chars end)

        if found do
          {Map.update!(acc, found, &[wd | &1]), rem}
        else
          {acc, [wd | rem]}
        end
      end)

    ordered =
      priority_kanji
      |> Enum.map(fn k -> {k, Enum.reverse(by_kanji[k])} end)
      |> Enum.filter(fn {_, words} -> words != [] end)

    {ordered, remaining}
  end

  defp build_balanced_kanji_lessons(word_data_list) do
    build_mixed_lesson_chunks(word_data_list, [])
  end

  defp build_mixed_lesson_chunks([], acc), do: Enum.reverse(acc)

  defp build_mixed_lesson_chunks(words, acc) do
    by_type = Enum.group_by(words, & &1.word_type)
    types = [:counter, :noun, :verb, :adjective, :adverb, :expression, :other]

    {lesson_words, remaining_by_type} =
      Enum.reduce(types, {[], %{}}, fn type, {picked, rem} ->
        case Map.get(by_type, type, []) do
          [first | rest] -> {[first | picked], Map.put(rem, type, rest)}
          [] -> {picked, Map.put(rem, type, [])}
        end
      end)

    all_remaining =
      remaining_by_type
      |> Map.values()
      |> Enum.concat()

    lesson_words =
      if length(lesson_words) < @words_per_lesson do
        lesson_words ++ Enum.take(all_remaining, @words_per_lesson - length(lesson_words))
      else
        Enum.take(lesson_words, @words_per_lesson)
      end

    if lesson_words == [] do
      Enum.reverse(acc)
    else
      used_ids = Enum.map(lesson_words, & &1.word.id) |> MapSet.new()
      new_remaining = Enum.filter(words, fn w -> not MapSet.member?(used_ids, w.word.id) end)
      build_mixed_lesson_chunks(new_remaining, [lesson_words | acc])
    end
  end

  defp build_mixed_lessons(word_data) do
    word_data
    |> Enum.sort_by(& &1.core_rank)
    |> Enum.chunk_every(@words_per_lesson)
  end

  defp get_word_kanji(word) do
    word.word_kanjis
    |> Enum.map(& &1.kanji.character)
    |> Enum.filter(& &1)
  end

  defp create_lesson(difficulty, order_index, word_data_list, dry_run) do
    words = Enum.map(word_data_list, & &1.word)
    _first_word = hd(words)

    title = generate_lesson_title(word_data_list, order_index)
    description = generate_lesson_description(words)

    lesson_attrs = %{
      title: title,
      description: description,
      difficulty: difficulty,
      order_index: order_index,
      lesson_type: :reading
    }

    if dry_run do
      if order_index <= 5 do
        word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")
        _types = word_data_list |> Enum.map(& &1.word_type) |> Enum.join(", ")
        Mix.shell().info("  [##{order_index}] #{title}")
        Mix.shell().info("      Words: #{word_texts}")

        Mix.shell().info(
          "      Core ranks: #{Enum.map(word_data_list, & &1.core_rank) |> Enum.join(", ")}"
        )
      end
    else
      existing =
        Lesson
        |> where(difficulty: ^difficulty, order_index: ^order_index)
        |> Repo.one()

      if existing do
        if rem(order_index, 50) == 0, do: Mix.shell().info("  ⚠ Exists: #{title}")
      else
        case Content.create_lesson_with_words(lesson_attrs, build_word_links(words)) do
          {:ok, _} ->
            if order_index <= 5 or rem(order_index, 50) == 0 do
              Mix.shell().info("  ✓ ##{order_index}: #{title}")
            end

          {:error, changeset} ->
            Mix.shell().error("  ✗ Failed: #{title}")
            IO.inspect(changeset.errors)
        end
      end
    end
  end

  defp generate_lesson_title(word_data_list, index) do
    words = Enum.map(word_data_list, & &1.word)
    first = hd(words)

    kanji = word_data_list |> Enum.flat_map(& &1.kanji_chars) |> Enum.uniq() |> Enum.join("")
    types = word_data_list |> Enum.map(& &1.word_type) |> Enum.uniq()

    type_str = if length(types) == 1, do: " #{hd(types)}s", else: " mix"

    cond do
      index <= 3 and kanji != "" ->
        "#{kanji} Basics"

      String.length(kanji) == 1 ->
        "#{kanji} Words"

      true ->
        "#{first.text}#{type_str}"
    end
  end

  defp generate_lesson_description(words) do
    word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")
    "Learn #{length(words)} words: #{word_texts}"
  end

  defp build_word_links(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, position} ->
      %{word_id: word.id, position: position}
    end)
  end

  defp delete_system_lessons(nil) do
    from(l in Lesson, where: l.difficulty in [1, 2, 3, 4, 5])
    |> Repo.delete_all()

    Mix.shell().info("Deleted all existing lessons")
  end

  defp delete_system_lessons(level) do
    from(l in Lesson, where: l.difficulty == ^level)
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing N#{level} lessons")
  end

  defp show_stats do
    by_level =
      from(l in Lesson, group_by: [l.difficulty], select: {l.difficulty, count(l.id)})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("")
    Mix.shell().info("=== Generated Lessons ===")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      count = Map.get(by_level, level, 0)
      core_range = core_range_for_jlpt(level) |> then(fn {min, max} -> "Core #{min}-#{max}" end)
      Mix.shell().info("  N#{level} (#{core_range}): #{count} lessons")
    end)
  end
end
