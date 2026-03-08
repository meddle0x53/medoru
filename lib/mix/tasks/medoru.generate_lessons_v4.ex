defmodule Mix.Tasks.Medoru.GenerateLessonsV4 do
  @moduledoc """
  Generates system vocabulary lessons with optimized kanji and word-type progression.

  This version implements a pedagogically sound lesson structure:

  1. **Phase 1: Short Focus Lessons** (Single kanji, short words only - 2-3 chars)
     - Numbers → Time → Directions → Common descriptors
     - Builds foundational kanji recognition with easy words

  2. **Phase 2: Themed Mixed Lessons** (Categorized by word type, interleaved)
     - Pattern: 2-3 Noun lessons → 1 Verb lesson → 1 Adjective lesson → repeat
     - Within each type, ordered by complexity (kana-only → single kanji → compound)
     - Thematic grouping (family, food, actions, descriptions)

  3. **Phase 3: Compound & Complex** (Multi-kanji words, expressions)
     - Building on learned kanji
     - Real-world phrases and expressions

  ## Progression Principles (based on JLPT and language learning research)

  - **N5** (~800 words, 100 kanji): Daily life, basic nouns, simple verbs/adjectives
  - **N4** (~1500 words, 300 kanji): Daily conversations, complex verb forms
  - **N3** (~3000 words, 650 kanji): Social/professional contexts, connectors

  ## Examples

      mix medoru.generate_lessons_v4              # Generate all levels
      mix medoru.generate_lessons_v4 --level N5   # N5 only
      mix medoru.generate_lessons_v4 --dry-run    # Preview
      mix medoru.generate_lessons_v4 --force      # Regenerate
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, Word, Kanji}

  import Ecto.Query

  require Logger

  @shortdoc "Generate lessons with optimized kanji and word-type progression"

  @words_per_lesson 4

  # Research-based kanji learning order
  @kanji_priority [
    # Tier 1: Numbers (Essential building blocks)
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
    # Tier 2: Time/Date (Daily life essential)
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
    # Tier 3: Direction/Location (Spatial understanding)
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
    "近",
    "遠",
    "方",
    "場",
    # Tier 4: Common descriptors (Adjective foundations)
    "大",
    "小",
    "高",
    "低",
    "長",
    "短",
    "新",
    "古",
    "多",
    "少",
    "良",
    "悪",
    "早",
    "遅",
    "易",
    "難",
    "暑",
    "寒",
    "楽",
    # Tier 5: People/Social (Human interactions)
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
    "名",
    "家",
    "自",
    "他",
    "私",
    "君",
    # Tier 6: Nature/Elements (Physical world)
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
    "空",
    "雨",
    "風",
    "雪",
    "花",
    "草",
    "林",
    "森",
    "海",
    "石",
    # Tier 7: Actions (Verb foundations)
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

  # Thematic categories for future use
  # @themes ["Family", "Actions", "Food", "Time", "Places", "Descriptions", "Numbers", "Work", "Shopping", "Travel"]

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
    Mix.shell().info("Generating optimized lessons for all JLPT levels...")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      Mix.shell().info("")
      Mix.shell().info("=== JLPT N#{level} ===")
      generate_lessons_for_level(level, dry_run)
    end)
  end

  defp generate_lessons(level, dry_run) do
    Mix.shell().info("Generating optimized lessons for JLPT N#{level}...")
    generate_lessons_for_level(level, dry_run)
  end

  defp generate_lessons_for_level(difficulty, dry_run) do
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

    # Enrich word data
    word_data = enrich_word_data(words, difficulty)

    # Phase 1: Short Focus Lessons (single kanji, short words 2-3 chars)
    {focus_lessons, remaining} = build_focus_lessons(word_data, difficulty)

    # Phase 2: Themed Mixed Lessons (interleaved word types)
    themed_lessons = build_themed_lessons(remaining)

    all_lessons = focus_lessons ++ themed_lessons

    Mix.shell().info("  Creating #{length(all_lessons)} lessons:")
    Mix.shell().info("    - Phase 1 (Focus): #{length(focus_lessons)} lessons")
    Mix.shell().info("    - Phase 2 (Themed): #{length(themed_lessons)} lessons")

    # Create lessons
    Enum.with_index(all_lessons, 1)
    |> Enum.each(fn {lesson_words, index} ->
      create_lesson(difficulty, index, lesson_words, dry_run)
    end)
  end

  defp enrich_word_data(words, difficulty) do
    kanji_priority_map = build_kanji_priority_map(difficulty)

    Enum.map(words, fn word ->
      kanji_chars = get_word_kanji(word)
      word_length = String.length(word.text)
      kanji_count = length(kanji_chars)

      # Determine complexity score
      complexity =
        case {word_length, kanji_count} do
          # Short kana words
          {l, 0} when l <= 3 -> 1
          # Short single-kanji
          {l, 1} when l <= 3 -> 2
          # Medium single-kanji
          {l, 1} when l <= 5 -> 3
          # Two-kanji
          {_, 2} -> 4
          # Complex
          {_, _} -> 5
        end

      # Get priority for first kanji
      first_kanji_priority =
        case kanji_chars do
          [first | _] -> Map.get(kanji_priority_map, first, 999)
          _ -> 999
        end

      %{
        word: word,
        kanji_chars: kanji_chars,
        kanji_count: kanji_count,
        word_length: word_length,
        word_type: word.word_type,
        complexity: complexity,
        frequency: word.usage_frequency || 1000,
        is_kana_only: kanji_chars == [],
        first_kanji_priority: first_kanji_priority,
        # For focus lessons: short words only
        eligible_for_focus: kanji_count == 1 and word_length <= 3
      }
    end)
  end

  defp build_kanji_priority_map(difficulty) do
    Kanji
    |> where(jlpt_level: ^difficulty)
    |> select([k], {k.character, k.frequency})
    |> Repo.all()
    |> Enum.reduce(%{}, fn {char, freq}, acc ->
      # Priority: custom order index * 1000 + frequency
      custom_index = Enum.find_index(@kanji_priority, &(&1 == char)) || 999
      priority = custom_index * 1000 + (freq || 1000)
      Map.put(acc, char, priority)
    end)
  end

  defp get_word_kanji(word) do
    word.word_kanjis
    |> Enum.map(& &1.kanji.character)
    |> Enum.filter(& &1)
  end

  # Phase 1: Build focus lessons for short single-kanji words
  defp build_focus_lessons(word_data, _difficulty) do
    # Separate focus-eligible words
    {focus_eligible, remaining} = Enum.split_with(word_data, & &1.eligible_for_focus)

    # Group by kanji
    focus_by_kanji =
      focus_eligible
      |> Enum.group_by(fn w -> hd(w.kanji_chars) end)
      |> Enum.map(fn {kanji, words} ->
        # Sort by frequency within each kanji
        {kanji, Enum.sort_by(words, & &1.frequency)}
      end)
      |> Enum.sort_by(fn {kanji, _} ->
        Enum.find_index(@kanji_priority, &(&1 == kanji)) || 999
      end)

    # Create lessons (max 2 lessons per kanji for focus phase)
    focus_lessons =
      focus_by_kanji
      |> Enum.flat_map(fn {_kanji, words} ->
        words
        |> Enum.chunk_every(@words_per_lesson)
        # Max 2 lessons per kanji in focus phase
        |> Enum.take(2)
      end)

    {focus_lessons,
     remaining ++ (focus_eligible -- Enum.concat(Enum.map(focus_by_kanji, fn {_, w} -> w end)))}
  end

  # Phase 2: Build themed lessons with interleaved word types
  defp build_themed_lessons(word_data) do
    # Group by word type
    by_type = Enum.group_by(word_data, & &1.word_type)

    nouns = Map.get(by_type, :noun, [])
    verbs = Map.get(by_type, :verb, [])
    adjectives = Map.get(by_type, :adjective, [])
    adverbs = Map.get(by_type, :adverb, [])
    others = Map.get(by_type, :other, []) ++ Map.get(by_type, :expression, [])

    # Sort each by complexity then frequency
    nouns = Enum.sort_by(nouns, &{&1.complexity, &1.frequency})
    verbs = Enum.sort_by(verbs, &{&1.complexity, &1.frequency})
    adjectives = Enum.sort_by(adjectives, &{&1.complexity, &1.frequency})
    adverbs = Enum.sort_by(adverbs, &{&1.complexity, &1.frequency})
    others = Enum.sort_by(others, &{&1.complexity, &1.frequency})

    # Interleave: 2-3 noun lessons → 1 verb → 1 adjective → repeat
    build_interleaved_lessons(nouns, verbs, adjectives, adverbs, others, [])
  end

  defp build_interleaved_lessons([], [], [], [], [], acc), do: Enum.reverse(acc)

  defp build_interleaved_lessons(nouns, verbs, adjectives, adverbs, others, acc) do
    # Take 2-3 noun lessons
    # Alternate 2,3,2,3...
    {noun_chunks, nouns_rest} = take_lessons(nouns, 2 + rem(length(acc), 2))

    # Take 1 verb lesson
    {verb_chunks, verbs_rest} = take_lessons(verbs, 1)

    # Take 1 adjective lesson
    {adj_chunks, adj_rest} = take_lessons(adjectives, 1)

    # Add any adverbs/others as fillers
    {filler_chunks, others_rest} = take_lessons(adverbs ++ others, 1)

    new_lessons = noun_chunks ++ verb_chunks ++ adj_chunks ++ filler_chunks

    if new_lessons == [] do
      Enum.reverse(acc)
    else
      build_interleaved_lessons(
        nouns_rest,
        verbs_rest,
        adj_rest,
        [],
        others_rest,
        new_lessons ++ acc
      )
    end
  end

  defp take_lessons(words, count) do
    words
    |> Enum.chunk_every(@words_per_lesson)
    |> Enum.split(count)
    |> case do
      {taken, rest} -> {taken, Enum.concat(rest)}
    end
  end

  defp create_lesson(difficulty, order_index, word_data_list, dry_run) do
    words = Enum.map(word_data_list, & &1.word)

    title = generate_lesson_title(word_data_list, order_index)
    description = generate_lesson_description(words, word_data_list)

    lesson_attrs = %{
      title: title,
      description: description,
      difficulty: difficulty,
      order_index: order_index,
      lesson_type: :reading
    }

    if dry_run do
      if order_index <= 20 do
        types = word_data_list |> Enum.map(& &1.word_type) |> Enum.join(", ")
        kanji = word_data_list |> Enum.flat_map(& &1.kanji_chars) |> Enum.uniq() |> Enum.join(" ")
        Mix.shell().info("  [DRY RUN ##{order_index}] #{title}")
        Mix.shell().info("     Words: #{Enum.map(words, & &1.text) |> Enum.join(", ")}")
        Mix.shell().info("     Types: #{types} | Kanji: #{kanji}")
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
            if order_index <= 20 or rem(order_index, 50) == 0 do
              Mix.shell().info("  ✓ Created ##{order_index}: #{lesson.title}")
            end

          {:error, changeset} ->
            Mix.shell().error("  ✗ Failed: #{title}")
            IO.inspect(changeset.errors, label: "Errors")
        end
      end
    end
  end

  defp generate_lesson_title(word_data_list, _index) do
    words = Enum.map(word_data_list, & &1.word)
    first_word = hd(words)
    all_kanji = Enum.flat_map(word_data_list, & &1.kanji_chars) |> Enum.uniq()
    word_types = word_data_list |> Enum.map(& &1.word_type) |> Enum.uniq()

    cond do
      # Phase 1: Focus lessons (single kanji, short)
      length(words) <= @words_per_lesson and length(all_kanji) == 1 and
          String.length(first_word.text) <= 3 ->
        kanji = hd(all_kanji)
        tier = get_kanji_tier(kanji)
        "#{kanji} Basics #{tier}"

      # Mixed type lesson
      length(word_types) > 1 ->
        "#{first_word.text} Mix"

      # Single type lesson
      true ->
        type = hd(word_types)
        "#{first_word.text} #{String.capitalize(to_string(type))}s"
    end
  end

  defp get_kanji_tier(kanji) do
    idx = Enum.find_index(@kanji_priority, &(&1 == kanji))

    cond do
      # Numbers
      idx < 13 -> "①"
      # Time
      idx < 26 -> "②"
      # Directions
      idx < 39 -> "③"
      # Descriptors
      idx < 52 -> "④"
      # People
      idx < 65 -> "⑤"
      # Nature
      idx < 78 -> "⑥"
      # Actions
      true -> "⑦"
    end
  end

  defp generate_lesson_description(words, word_data_list) do
    word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")

    type_counts =
      word_data_list
      |> Enum.group_by(& &1.word_type)
      |> Enum.map(fn {type, list} -> "#{length(list)} #{type}" end)
      |> Enum.join(", ")

    complexity_info =
      word_data_list
      |> Enum.map(fn w ->
        cond do
          w.is_kana_only -> "kana"
          w.kanji_count == 1 -> "1K"
          true -> "#{w.kanji_count}K"
        end
      end)
      |> Enum.join(", ")

    "Learn #{length(words)} words (#{type_counts}). Complexity: #{complexity_info}. Words: #{word_texts}"
  end

  defp build_word_links(words) do
    words
    |> Enum.with_index()
    |> Enum.map(fn {word, position} ->
      %{word_id: word.id, position: position}
    end)
  end

  defp delete_system_lessons(nil) do
    from(l in Lesson,
      where:
        like(l.title, "%Basics%") or like(l.title, "%Mix%") or
          like(l.title, "%Nouns%") or like(l.title, "%Verbs%") or
          like(l.title, "%Adjectives%") or like(l.title, "%Adverbs%")
    )
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing system lessons")
  end

  defp delete_system_lessons(level) do
    from(l in Lesson,
      where:
        l.difficulty == ^level and
          (like(l.title, "%Basics%") or like(l.title, "%Mix%") or
             like(l.title, "%Nouns%") or like(l.title, "%Verbs%") or
             like(l.title, "%Adjectives%") or like(l.title, "%Adverbs%"))
    )
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing N#{level} system lessons")
  end

  defp show_stats do
    total_lessons =
      from(l in Lesson,
        where:
          like(l.title, "%Basics%") or like(l.title, "%Mix%") or
            like(l.title, "%Nouns%") or like(l.title, "%Verbs%")
      )
      |> Repo.aggregate(:count, :id)

    by_level =
      from(l in Lesson,
        where:
          like(l.title, "%Basics%") or like(l.title, "%Mix%") or
            like(l.title, "%Nouns%") or like(l.title, "%Verbs%")
      )
      |> group_by([l], l.difficulty)
      |> select([l], {l.difficulty, count(l.id)})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("")
    Mix.shell().info("=== Optimized Vocabulary Lessons ===")
    Mix.shell().info("Total Lessons: #{total_lessons}")
    Mix.shell().info("")
    Mix.shell().info("By JLPT Level:")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      count = Map.get(by_level, level, 0)
      Mix.shell().info("  N#{level}: #{count} lessons")
    end)

    Mix.shell().info("")
    Mix.shell().info("Lesson Structure:")
    Mix.shell().info("  Phase 1: Short Focus (single kanji, 2-3 char words)")
    Mix.shell().info("  Phase 2: Themed Mixed (2-3 noun → 1 verb → 1 adj cycles)")
    Mix.shell().info("")
    Mix.shell().info("Progression:")

    Mix.shell().info(
      "  ① Numbers → ② Time → ③ Directions → ④ Descriptors → ⑤ People → ⑥ Nature → ⑦ Actions"
    )
  end

  defp return, do: :ok
end
