defmodule Mix.Tasks.Medoru.GenerateLessonsV5 do
  @moduledoc """
  Generates system vocabulary lessons with proper kanji filtering and balanced ordering.

  Key improvements:
  1. FIX: Proper kanji filtering (only N5 kanji in N5 lessons)
  2. Number kanji come first (一, 二, 三...)
  3. Balanced mix: Each lesson has varied word types, not noun-heavy
  4. Progressive complexity within each kanji group

  ## Examples

      mix medoru.generate_lessons_v5              # Generate all levels
      mix medoru.generate_lessons_v5 --level N5   # N5 only
      mix medoru.generate_lessons_v5 --dry-run    # Preview
      mix medoru.generate_lessons_v5 --force      # Regenerate
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, Word, Kanji}

  import Ecto.Query

  require Logger

  @shortdoc "Generate lessons with proper kanji filtering and balanced ordering"

  @words_per_lesson 4

  # Research-based kanji learning order - Numbers FIRST
  @kanji_priority [
    # Tier 1: Numbers (Most essential - come first!)
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
    # Tier 2: Time/Date
    "日",
    "月",
    "年",
    "時",
    "分",
    "週",
    "間",
    "朝",
    "昼",
    "夜",
    "今",
    "昨",
    "明",
    # Tier 3: People/Family
    "人",
    "子",
    "女",
    "男",
    "友",
    "先",
    "生",
    "母",
    "父",
    "兄",
    "弟",
    "姉",
    "妹",
    # Tier 4: Directions/Location
    "上",
    "下",
    "中",
    "左",
    "右",
    "前",
    "後",
    "外",
    "内",
    "東",
    "西",
    "南",
    "北",
    # Tier 5: Descriptors
    "大",
    "小",
    "高",
    "長",
    "新",
    "古",
    "多",
    "少",
    "良",
    "悪",
    "早",
    "楽",
    # Tier 6: Nature
    "山",
    "川",
    "田",
    "天",
    "気",
    "火",
    "水",
    "木",
    "金",
    "土",
    "雨",
    "花",
    # Tier 7: Actions
    "見",
    "行",
    "来",
    "食",
    "飲",
    "話",
    "読",
    "書",
    "聞",
    "言",
    "思",
    "知",
    "入",
    "出",
    "立",
    "会",
    "買",
    "売",
    "待",
    "持",
    "住",
    "作",
    "使",
    "開"
  ]

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
    # FIX: Get kanji AT this level or EASIER (higher number = easier)
    # N5 = level 5, N4 = level 4, N1 = level 1
    # For N5 lessons, we only want kanji with jlpt_level >= 5 (N5 only)
    allowed_kanji_chars =
      Kanji
      |> where([k], k.jlpt_level >= ^difficulty)
      |> select([k], {k.character, k.jlpt_level})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("  Allowed kanji: #{map_size(allowed_kanji_chars)}")

    # Get all words at this difficulty
    words =
      Word
      |> where(difficulty: ^difficulty)
      |> preload(word_kanjis: :kanji)
      |> Repo.all()

    # STRICT filtering: Only words where ALL kanji are at or below this level
    filtered_words =
      Enum.filter(words, fn word ->
        word_kanjis = get_word_kanji(word)

        # Kana-only words are always allowed
        if word_kanjis == [] do
          true
        else
          # All kanji in this word must be in the allowed set
          Enum.all?(word_kanjis, fn char -> Map.has_key?(allowed_kanji_chars, char) end)
        end
      end)

    filtered_count = length(words) - length(filtered_words)

    Mix.shell().info(
      "  Words: #{length(words)} total, #{length(filtered_words)} valid (removed #{filtered_count})"
    )

    if filtered_words == [] do
      Mix.shell().info("  No valid words for N#{difficulty}")
    else
      # Build lessons with balanced ordering
      lessons = build_balanced_lessons(filtered_words, difficulty)

      Mix.shell().info("  Creating #{length(lessons)} lessons...")

      # Create lessons
      Enum.with_index(lessons, 1)
      |> Enum.each(fn {lesson_words, index} ->
        create_lesson(difficulty, index, lesson_words, dry_run)
      end)
    end
  end

  defp build_balanced_lessons(words, _difficulty) do
    # Sort by pre-computed sort_score (frequency + visual complexity)
    # This orders: most common first, then by complexity (1k, 1k+1, 1k+2, 2k, 2k+1, etc)
    word_data = enrich_word_data(words)

    # Group by priority kanji for thematic lessons
    {by_priority_kanji, remaining} = group_by_priority_kanji(word_data)

    # Build lessons in priority order, with balanced word types
    kanji_lessons =
      Enum.flat_map(by_priority_kanji, fn {_kanji, words_for_kanji} ->
        # Sort by pre-computed sort_score
        sorted = Enum.sort_by(words_for_kanji, & &1.sort_score)
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

  defp group_by_priority_kanji(word_data) do
    # For each word, find which priority kanji it contains (if any)
    priority_map = Map.new(@kanji_priority, fn k -> {k, []} end)

    {by_kanji, remaining} =
      Enum.reduce(word_data, {priority_map, []}, fn wd, {acc, rem} ->
        # Find the highest priority kanji in this word
        found = Enum.find(@kanji_priority, fn k -> k in wd.kanji_chars end)

        if found do
          {Map.update!(acc, found, &[wd | &1]), rem}
        else
          {acc, [wd | rem]}
        end
      end)

    # Convert to ordered list (respecting @kanji_priority order)
    ordered =
      @kanji_priority
      |> Enum.map(fn k -> {k, Enum.reverse(by_kanji[k])} end)
      |> Enum.filter(fn {_, words} -> words != [] end)

    {ordered, remaining}
  end

  defp build_balanced_kanji_lessons(word_data_list) do
    # Build lessons with mixed word types
    build_mixed_lesson_chunks(word_data_list, [])
  end

  defp build_mixed_lesson_chunks([], acc), do: Enum.reverse(acc)

  defp build_mixed_lesson_chunks(words, acc) do
    # Take words in a balanced way - prioritize variety
    by_type = Enum.group_by(words, & &1.word_type)
    types = [:counter, :noun, :verb, :adjective, :adverb, :other]

    # Pick one word from each type if available
    {lesson_words, remaining_by_type} =
      Enum.reduce(types, {[], %{}}, fn type, {picked, rem} ->
        case Map.get(by_type, type, []) do
          [first | rest] -> {[first | picked], Map.put(rem, type, rest)}
          [] -> {picked, Map.put(rem, type, [])}
        end
      end)

    # Fill remaining slots from other words
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
    # Chunk remaining words into mixed lessons, sorted by pre-computed score
    word_data
    |> Enum.sort_by(& &1.sort_score)
    |> Enum.chunk_every(@words_per_lesson)
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
        sort_score: word.sort_score || 999_999,
        frequency: word.usage_frequency || 1000
      }
    end)
  end

  defp get_word_kanji(word) do
    word.word_kanjis
    |> Enum.map(& &1.kanji.character)
    |> Enum.filter(& &1)
  end

  defp create_lesson(difficulty, order_index, word_data_list, dry_run) do
    words = Enum.map(word_data_list, & &1.word)

    # Generate title based on content
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
      if order_index <= 10 do
        word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")
        types = word_data_list |> Enum.map(& &1.word_type) |> Enum.join(", ")
        Mix.shell().info("  [##{order_index}] #{title}")
        Mix.shell().info("      Words: #{word_texts}")
        Mix.shell().info("      Types: #{types}")
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
            if order_index <= 10 or rem(order_index, 50) == 0 do
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

    # Get kanji used
    kanji = word_data_list |> Enum.flat_map(& &1.kanji_chars) |> Enum.uniq() |> Enum.join("")

    # Get types
    types = word_data_list |> Enum.map(& &1.word_type) |> Enum.uniq()
    type_str = if length(types) == 1, do: " #{hd(types)}s", else: " mix"

    cond do
      # First few lessons with numbers
      index <= 3 and kanji != "" ->
        "#{kanji} Basics"

      # Single kanji focus
      String.length(kanji) == 1 ->
        "#{kanji} Words"

      # Mixed
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
      Mix.shell().info("  N#{level}: #{count} lessons")
    end)
  end
end
