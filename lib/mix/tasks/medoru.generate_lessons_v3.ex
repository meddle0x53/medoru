defmodule Mix.Tasks.Medoru.GenerateLessonsV3 do
  @moduledoc """
  Generates system vocabulary lessons with intelligent kanji progression.

  This version implements a research-based kanji learning progression:
  1. Numbers (一-十) and basic counting - first priority
  2. Time/Date kanji (日, 月, 年, 時) - essential for daily use
  3. Direction/Location (上, 下, 中, 左, 右, 前, 後)
  4. Common descriptors (大, 小, 高, 長, 新, 古, 多, 少)
  5. People-related (人, 子, 女, 男, 友, 名, 先, 生)
  6. Nature elements (山, 川, 田, 天, 気, 火, 水, 木, 金, 土)
  7. Actions/Verbs (見, 行, 来, 食, 飲, 話, 読, 書, 聞)
  8. Common compounds using learned kanji
  9. Remaining single kanji by frequency
  10. Multi-kanji compounds

  ## Examples

      mix medoru.generate_lessons_v3              # Generate all levels
      mix medoru.generate_lessons_v3 --level N5   # N5 only
      mix medoru.generate_lessons_v3 --dry-run    # Preview
      mix medoru.generate_lessons_v3 --force      # Regenerate
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, LessonWord, Word, Kanji}

  import Ecto.Query

  require Logger

  @shortdoc "Generate lessons with research-based kanji progression"

  @words_per_lesson 4

  # Research-based kanji learning order (prioritized by frequency and utility)
  @kanji_priority_order [
    # Numbers (Tier 1: Essential)
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
    # Time/Date (Tier 2: Daily life essential)
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
    # Direction/Location (Tier 3: Spatial concepts)
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
    # Common descriptors (Tier 4: Adjectives/attributes)
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
    # People (Tier 5: Social interactions)
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
    "私",
    "自",
    "他",
    "方",
    "者",
    # Nature elements (Tier 6: Basic elements)
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
    "川",
    # Common verbs/actions (Tier 7: Essential actions)
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
    "開",
    "閉",
    # School/learning (Tier 8: Education context)
    "学",
    "校",
    "教",
    "室",
    "本",
    "文",
    "字",
    "語",
    "英",
    "算",
    "数",
    "理",
    # Common objects/places (Tier 9)
    "車",
    "道",
    "店",
    "駅",
    "国",
    "市",
    "村",
    "町",
    "社",
    "店",
    "院",
    "館",
    # Abstract/common (Tier 10)
    "事",
    "物",
    "思",
    "言",
    "手",
    "目",
    "口",
    "耳",
    "心",
    "力",
    "体",
    "頭",
    "顔",
    "足",
    "道",
    "社",
    "員",
    "月",
    "曜",
    "番",
    "毎",
    "何",
    "万"
  ]

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
    Mix.shell().info("Generating lessons with intelligent kanji progression...")

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

    # Create kanji priority map for this level
    kanji_priority = build_kanji_priority_map(difficulty)

    # Sort single kanji words by priority
    single_kanji =
      kanji_words
      |> Enum.filter(&(&1.kanji_count == 1))
      |> Enum.sort_by(fn w ->
        kanji = hd(w.kanji_chars)
        priority = Map.get(kanji_priority, kanji, 999)
        {priority, w.frequency}
      end)

    # Group single kanji words by their kanji (maintaining priority order)
    single_kanji_lessons =
      single_kanji
      |> Enum.chunk_by(fn w -> hd(w.kanji_chars) end)
      |> Enum.flat_map(&chunk_into_lessons(&1, @words_per_lesson))

    # Multi-kanji words - sort by complexity and frequency
    multi_kanji =
      kanji_words
      |> Enum.filter(&(&1.kanji_count >= 2))
      |> Enum.sort_by(&{&1.kanji_count, &1.frequency})

    # For multi-kanji, try to group words that share kanji
    multi_kanji_lessons = build_multi_kanji_lessons(multi_kanji, @words_per_lesson)

    # Combine: kana first, then prioritized single kanji, then multi-kanji
    all_lessons =
      chunk_into_lessons(kana_words, @words_per_lesson) ++
        single_kanji_lessons ++ multi_kanji_lessons

    Mix.shell().info("  Creating #{length(all_lessons)} lessons")

    Mix.shell().info(
      "    - Kana: #{length(chunk_into_lessons(kana_words, @words_per_lesson))} lessons"
    )

    Mix.shell().info("    - Single kanji: #{length(single_kanji_lessons)} lessons")
    Mix.shell().info("    - Multi-kanji: #{length(multi_kanji_lessons)} lessons")

    # Create lessons
    Enum.with_index(all_lessons, 1)
    |> Enum.each(fn {lesson_words, index} ->
      create_lesson(difficulty, index, lesson_words, dry_run)
    end)
  end

  defp build_kanji_priority_map(jlpt_level) do
    # Get kanji for this level
    level_kanji =
      Kanji
      |> where(jlpt_level: ^jlpt_level)
      |> select([k], k.character)
      |> Repo.all()
      |> MapSet.new()

    # Build priority map
    @kanji_priority_order
    |> Enum.with_index(1)
    |> Enum.filter(fn {char, _} -> MapSet.member?(level_kanji, char) end)
    |> Map.new()
  end

  defp chunk_into_lessons(words, size) do
    words
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.take(&1, size))
    |> Enum.filter(&(&1 != []))
  end

  defp build_multi_kanji_lessons(word_data, size) do
    # Sort by frequency first to prioritize common words
    sorted = Enum.sort_by(word_data, & &1.frequency)

    # Simple chunking for now - could be enhanced to group by shared kanji
    chunk_into_lessons(sorted, size)
  end

  defp create_lesson(difficulty, order_index, word_data_list, dry_run) do
    words = Enum.map(word_data_list, & &1.word)

    title = generate_lesson_title(word_data_list)
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
        kanji_in_lesson =
          word_data_list
          |> Enum.flat_map(& &1.kanji_chars)
          |> Enum.uniq()

        Mix.shell().info("  [DRY RUN ##{order_index}] #{title}")
        Mix.shell().info("     Words: #{Enum.map(words, & &1.text) |> Enum.join(", ")}")
        Mix.shell().info("     Kanji: #{Enum.join(kanji_in_lesson, " ")}")
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

  defp generate_lesson_title(word_data_list) do
    all_kanji =
      word_data_list
      |> Enum.flat_map(& &1.kanji_chars)
      |> Enum.uniq()

    all_kana = Enum.all?(word_data_list, & &1.is_kana_only)

    cond do
      all_kana ->
        first = hd(word_data_list).word.text
        "#{first} (Kana)"

      length(all_kanji) == 1 ->
        kanji = hd(all_kanji)
        tier = get_kanji_tier(kanji)
        "#{kanji} Focus #{tier}"

      length(all_kanji) == 2 ->
        "#{Enum.join(all_kanji, "")} Combo"

      true ->
        first_word = hd(word_data_list).word.text
        "#{first_word} Set"
    end
  end

  defp get_kanji_tier(kanji) do
    cond do
      kanji in ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "百", "千", "万"] ->
        "①"

      kanji in ["日", "月", "年", "時", "分", "週", "間", "朝", "昼", "夜", "今", "昨", "明"] ->
        "②"

      kanji in ["上", "下", "中", "左", "右", "前", "後", "外", "内", "東", "西", "南", "北"] ->
        "③"

      kanji in ["大", "小", "高", "低", "長", "短", "新", "古", "多", "少", "良", "悪", "早", "遅"] ->
        "④"

      kanji in ["人", "子", "女", "男", "友", "先", "生", "母", "父", "兄", "弟", "姉", "妹"] ->
        "⑤"

      kanji in ["山", "川", "田", "天", "気", "火", "水", "木", "金", "土", "空", "雨", "風"] ->
        "⑥"

      kanji in ["見", "行", "来", "食", "飲", "話", "読", "書", "聞", "言", "思", "知"] ->
        "⑦"

      true ->
        "⑧+"
    end
  end

  defp generate_lesson_description(words, word_data_list) do
    word_texts = Enum.map(words, & &1.text) |> Enum.join(", ")

    kana_count = Enum.count(word_data_list, & &1.is_kana_only)
    one_kanji = Enum.count(word_data_list, &(&1.kanji_count == 1 and not &1.is_kana_only))
    multi_kanji = Enum.count(word_data_list, &(&1.kanji_count >= 2))

    complexity =
      cond do
        kana_count > 0 and one_kanji == 0 and multi_kanji == 0 -> "#{kana_count} kana-only"
        kana_count == 0 and one_kanji > 0 and multi_kanji == 0 -> "#{one_kanji} single-kanji"
        multi_kanji > 0 -> "#{kana_count} kana, #{one_kanji} single, #{multi_kanji} multi-kanji"
        true -> "#{kana_count} kana, #{one_kanji} single-kanji"
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
    from(l in Lesson,
      where:
        like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
          like(l.title, "%Combo%") or like(l.title, "%Set%")
    )
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing system lessons")
  end

  defp delete_system_lessons(level) do
    from(l in Lesson,
      where:
        l.difficulty == ^level and
          (like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
             like(l.title, "%Combo%") or like(l.title, "%Set%"))
    )
    |> Repo.delete_all()

    Mix.shell().info("Deleted existing N#{level} system lessons")
  end

  defp show_stats do
    total_lessons =
      from(l in Lesson,
        where:
          like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
            like(l.title, "%Combo%") or like(l.title, "%Set%")
      )
      |> Repo.aggregate(:count, :id)

    by_level =
      from(l in Lesson,
        where:
          like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
            like(l.title, "%Combo%") or like(l.title, "%Set%")
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
          like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
            like(l.title, "%Combo%") or like(l.title, "%Set%")
      )
      |> Repo.aggregate(:count, :id)

    avg_words =
      if total_lessons > 0 do
        Float.round(total_lesson_words / total_lessons, 1)
      else
        0
      end

    Mix.shell().info("")
    Mix.shell().info("=== Intelligent Kanji Progression Lessons ===")
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
              (like(l.title, "%Kana%") or like(l.title, "%(Kana)") or like(l.title, "%Focus%") or
                 like(l.title, "%Combo%") or like(l.title, "%Set%"))
        )
        |> Repo.aggregate(:count, :id)

      Mix.shell().info("  N#{level}: #{count} lessons (#{word_count} words)")
    end)

    Mix.shell().info("")
    Mix.shell().info("Progression tiers:")
    Mix.shell().info("  ① Numbers (一-十, 百, 千, 万)")
    Mix.shell().info("  ② Time/Date (日, 月, 年, 時, etc.)")
    Mix.shell().info("  ③ Directions (上, 下, 中, 左, 右, etc.)")
    Mix.shell().info("  ④ Descriptors (大, 小, 高, 長, etc.)")
    Mix.shell().info("  ⑤ People (人, 子, 女, 男, 友, etc.)")
    Mix.shell().info("  ⑥ Nature (山, 川, 天, 気, 水, etc.)")
    Mix.shell().info("  ⑦ Verbs (見, 行, 来, 食, 話, etc.)")
    Mix.shell().info("  ⑧+ Others by frequency")
  end

  defp return, do: :ok
end
