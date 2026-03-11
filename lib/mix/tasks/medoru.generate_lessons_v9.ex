defmodule Mix.Tasks.Medoru.GenerateLessonsV9 do
  @moduledoc """
  Generate N5/N4/N3 lessons with hand-curated, pedagogically sound vocabulary.

  Uses carefully selected words for each lesson topic to ensure meaningful learning progression.

  ## Examples
      mix medoru.generate_lessons_v9         # Generate all levels
      mix medoru.generate_lessons_v9 --n5    # Generate only N5
      mix medoru.generate_lessons_v9 --n4    # Generate only N4
      mix medoru.generate_lessons_v9 --n3    # Generate only N3
  """
  use Mix.Task
  require Logger

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.Word
  alias Medoru.Tests

  @requirements ["app.start"]

  # ========== N5 CURRICULUM ==========
  @n5_curriculum [
    # === PHASE 1: ABSOLUTE BASICS ===
    %{order: 1, title: "Numbers 1-5", words: ["一", "二", "三", "四", "五"]},
    %{order: 2, title: "Numbers 6-10", words: ["六", "七", "八", "九", "十"]},
    %{order: 3, title: "Basic Greetings", words: ["おはよう", "こんにちは", "こんばんは", "さようなら", "ありがとう"]},
    %{order: 4, title: "Self-Introduction", words: ["私", "名前", "はじめまして", "どうぞよろしく", "人"]},
    %{order: 5, title: "Basic Pronouns", words: ["私", "あなた", "彼", "彼女", "友達"]},

    # === PHASE 2: FAMILY ===
    %{order: 6, title: "Family Members", words: ["家族", "父", "母", "兄", "姉"]},
    %{order: 7, title: "More Family", words: ["弟", "妹", "お父さん", "お母さん", "子供"]},

    # === PHASE 3: TIME ===
    %{order: 8, title: "Days of the Week", words: ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日"]},
    %{order: 9, title: "Time Words", words: ["今日", "明日", "昨日", "今", "時"]},
    %{order: 10, title: "Calendar", words: ["年", "月", "日", "週", "誕生日"]},

    # === PHASE 4: PLACES ===
    %{order: 11, title: "Places in Town", words: ["学校", "駅", "店", "公園", "病院"]},
    %{order: 12, title: "Home", words: ["家", "部屋", "台所", "風呂", "玄関"]},

    # === PHASE 5: FOOD & DRINK ===
    %{order: 13, title: "Food Staples", words: ["ご飯", "パン", "肉", "魚", "野菜"]},
    %{order: 14, title: "Drinks", words: ["水", "お茶", "コーヒー", "牛乳", "ジュース"]},
    %{order: 15, title: "Eating", words: ["食べる", "飲む", "朝ご飯", "昼", "晩"]},

    # === PHASE 6: ACTIONS ===
    %{order: 16, title: "Movement", words: ["行く", "来る", "帰る", "歩く", "乗る"]},
    %{order: 17, title: "Daily Actions", words: ["見る", "聞く", "話す", "読む", "書く"]},

    # === PHASE 7: ADJECTIVES ===
    %{order: 18, title: "Sizes", words: ["大きい", "小さい", "長い", "短い", "高い"]},
    %{order: 19, title: "Qualities", words: ["新しい", "古い", "良い", "悪い", "楽しい"]},
    %{order: 20, title: "Colors", words: ["赤い", "青い", "白い", "黒い", "色"]},

    # === PHASE 8: SHOPPING ===
    %{order: 21, title: "Shopping", words: ["買う", "売る", "お金", "値段", "安い"]},
    %{order: 22, title: "Money", words: ["円", "お金", "高い", "割引", "無料"]},

    # === PHASE 9: BODY & HEALTH ===
    %{order: 23, title: "Body Parts", words: ["目", "耳", "口", "手", "足"]},
    %{order: 24, title: "Health", words: ["病気", "薬", "病院", "医者", "痛い"]},

    # === PHASE 10: WEATHER & NATURE ===
    %{order: 25, title: "Weather", words: ["天気", "雨", "雪", "風", "暑い"]},
    %{order: 26, title: "Nature", words: ["山", "川", "海", "木", "花"]},

    # === PHASE 11: SCHOOL & WORK ===
    %{order: 27, title: "School", words: ["先生", "生徒", "教室", "教科書", "試験"]},
    %{order: 28, title: "Work", words: ["会社", "社員", "仕事", "会議", "忙しい"]},

    # === PHASE 12: EMOTIONS ===
    %{order: 29, title: "Feelings", words: ["好き", "嫌い", "欲しい", "嬉しい", "悲しい"]},
    %{order: 30, title: "Expressions", words: ["お願い", "すみません", "大丈夫", "楽しみ", "残念"]}
  ]

  # ========== N4 CURRICULUM ==========
  @n4_curriculum [
    # === PHASE 1: REVIEW & EXPANSION ===
    %{order: 1, title: "Numbers 11-100", words: ["十一", "二十", "百", "千", "万"]},
    %{order: 2, title: "Time Expressions", words: ["朝", "昼", "晩", "夜", "毎日"]},
    %{order: 3, title: "Duration", words: ["時間", "分", "秒", "週間", "ヶ月"]},

    # === PHASE 2: ADVANCED VERBS ===
    %{order: 4, title: "Changes", words: ["始める", "終わる", "変わる", "増える", "減る"]},
    %{order: 5, title: "Communication", words: ["伝える", "教える", "聞く", "答える", "相談"]},
    %{order: 6, title: "Work Actions", words: ["働く", "休む", "続ける", "辞める", "探す"]},

    # === PHASE 3: EMOTIONS & MENTAL ===
    %{order: 7, title: "Emotions 1", words: ["怒る", "驚く", "困る", "恥ずかしい", "羨ましい"]},
    %{order: 8, title: "Emotions 2", words: ["心配", "安心", "怖い", "安心する", "緊張"]},
    %{order: 9, title: "Thinking", words: ["思う", "考える", "信じる", "忘れる", "覚える"]},

    # === PHASE 4: ABSTRACT CONCEPTS ===
    %{order: 10, title: "Quality", words: ["大事", "大切", "簡単", "複雑", "便利"]},
    %{order: 11, title: "Amount", words: ["十分", "足りる", "足りない", "多すぎる", "少ない"]},
    %{order: 12, title: "Degree", words: ["特別", "普通", "一般的", "主な", "確か"]},

    # === PHASE 5: SOCIETY ===
    %{order: 13, title: "People", words: ["大人", "女性", "男性", "客", "主婦"]},
    %{order: 14, title: "Relationships", words: ["関係", "仲", "付き合い", "知り合い", "恋人"]},
    %{order: 15, title: "Society", words: ["社会", "文化", "習慣", "礼儀", "マナー"]},

    # === PHASE 6: DAILY LIFE ===
    %{order: 16, title: "Household", words: ["家事", "洗濯", "掃除", "料理", "買い物"]},
    %{order: 17, title: "Daily Routine", words: ["起きる", "寝る", "着る", "脱ぐ", "洗う"]},
    %{order: 18, title: "Transport", words: ["運転", "降りる", "乗り換え", "通る", "渡る"]},

    # === PHASE 7: LEISURE ===
    %{order: 19, title: "Entertainment", words: ["趣味", "映画", "音楽", "漫画", "旅行"]},
    %{order: 20, title: "Sports", words: ["運動", "試合", "練習", "勝つ", "負ける"]},
    %{order: 21, title: "Hobbies", words: ["集める", "作る", "描く", "撮る", "編む"]},

    # === PHASE 8: PROBLEMS ===
    %{order: 22, title: "Trouble", words: ["故障", "事故", "間違い", "遅刻", "忘れ物"]},
    %{order: 23, title: "Difficulties", words: ["失敗", "苦労", "我慢", "我慢する", "諦める"]},
    %{order: 24, title: "Safety", words: ["危険", "安全", "注意", "警告", "免許"]},

    # === PHASE 9: OPINIONS ===
    %{order: 25, title: "Agree/Disagree", words: ["賛成", "反対", "当然", "おかしい", "無理"]},
    %{order: 26, title: "Possibility", words: ["可能", "不可能", "许る", "許可", "禁止"]},
    %{order: 27, title: "Evaluation", words: ["正しい", "間違い", "適当", "不適当", "最高"]},

    # === PHASE 10: ACADEMIC ===
    %{order: 28, title: "Study", words: ["復習", "予習", "提出", "提出する", "レポート"]},
    %{order: 29, title: "Research", words: ["調べる", "調査", "実験", "結果", "発表"]},
    %{order: 30, title: "Language", words: ["文法", "単語", "発音", "意味", "翻訳"]},

    # === PHASE 11: BUSINESS ===
    %{order: 31, title: "Office", words: ["書類", "資料", "受付", "秘書", "部長"]},
    %{order: 32, title: "Business", words: ["商売", "取引", "契約", "利益", "損失"]},
    %{order: 33, title: "Technology", words: ["機械", "操作", "設定", "画面", "ソフト"]},

    # === PHASE 12: HEALTH ===
    %{order: 34, title: "Body More", words: ["頭", "顔", "首", "肩", "背中"]},
    %{order: 35, title: "Symptoms", words: ["熱", "咳", "頭痛", "腹痛", "吐き気"]}
  ]

  # ========== N3 CURRICULUM ==========
  @n3_curriculum [
    # === PHASE 1: SOCIETY & POLITICS ===
    %{order: 1, title: "Politics", words: ["政治", "経済", "国民", "選挙", "法律"]},
    %{order: 2, title: "Rights & Duties", words: ["権利", "義務", "平和", "戦争", "自由"]},
    %{order: 3, title: "Government", words: ["政府", "国家", "議会", "政策", "制度"]},

    # === PHASE 2: ECONOMY & BUSINESS ===
    %{order: 4, title: "Economy", words: ["経済", "貿易", "市場", "価格", "値段"]},
    %{order: 5, title: "Finance", words: ["給料", "税金", "貯金", "保険", "融資"]},
    %{order: 6, title: "Business", words: ["商売", "取引", "契約", "利益", "損失"]},
    %{order: 7, title: "Company", words: ["企業", "業界", "経営", "販売", "生産"]},

    # === PHASE 3: EDUCATION & RESEARCH ===
    %{order: 8, title: "University", words: ["大学", "学科", "教授", "講義", "研究"]},
    %{order: 9, title: "Academic", words: ["論文", "発表", "留学", "知識", "学問"]},
    %{order: 10, title: "Research", words: ["調査", "実験", "分析", "確認", "観察"]},

    # === PHASE 4: HEALTH & MEDICAL ===
    %{order: 11, title: "Health", words: ["健康", "病気", "症状", "治療", "手術"]},
    %{order: 12, title: "Medical", words: ["薬局", "医療", "診察", "看護", "患者"]},
    %{order: 13, title: "Body & Mind", words: ["疲労", "緊張", "回復", "予防", "診断"]},

    # === PHASE 5: ENVIRONMENT ===
    %{order: 14, title: "Nature", words: ["自然", "動物", "植物", "生物", "地球"]},
    %{order: 15, title: "Environment", words: ["環境", "資源", "電力", "保護", "破壊"]},

    # === PHASE 6: COMMUNICATION ===
    %{order: 16, title: "Information", words: ["情報", "連絡", "報告", "相談", "説明"]},
    %{order: 17, title: "Expression", words: ["発表", "紹介", "意見", "感想", "主張"]},
    %{order: 18, title: "Media", words: ["新聞", "雑誌", "出版", "記事", "広告"]},

    # === PHASE 7: EMOTIONS & MENTAL ===
    %{order: 19, title: "Complex Emotions", words: ["感情", "感動", "緊張", "不安", "心配"]},
    %{order: 20, title: "Mental States", words: ["失望", "後悔", "羨望", "期待", "希望"]},
    %{order: 21, title: "Psychology", words: ["理性", "感情", "意識", "心理", "態度"]},

    # === PHASE 8: ABSTRACT CONCEPTS ===
    %{order: 22, title: "Situations", words: ["状況", "状態", "場合", "機会", "情勢"]},
    %{order: 23, title: "Relations", words: ["関係", "影響", "原因", "結果", "目的"]},
    %{order: 24, title: "Logic", words: ["理由", "手段", "方法", "過程", "結論"]},

    # === PHASE 9: WORK & CAREER ===
    %{order: 25, title: "Career", words: ["就職", "転職", "退職", "定年", "経歴"]},
    %{order: 26, title: "Work Life", words: ["残業", "出勤", "退勤", "出張", "転勤"]},
    %{order: 27, title: "Skills", words: ["能力", "技術", "知識", "経験", "専門"]},

    # === PHASE 10: SOCIAL LIFE ===
    %{order: 28, title: "Community", words: ["地域", "市民", "住民", "社会", "福祉"]},
    %{order: 29, title: "Events", words: ["行事", "祭り", "式典", "会議", "集会"]},
    %{order: 30, title: "Services", words: ["公共", "交通", "施設", "機関", "役所"]},

    # === PHASE 11: MODERN LIFE ===
    %{order: 31, title: "Technology", words: ["技術", "機械", "操作", "設定", "制度"]},
    %{order: 32, title: "Internet", words: ["通信", "接続", "検索", "登録", "更新"]},
    %{order: 33, title: "Daily Conveniences", words: ["自動", "簡単", "快適", "便利", "効率"]},

    # === PHASE 12: CULTURE ===
    %{order: 34, title: "Art", words: ["美術", "芸術", "作品", "作家", "展覧"]},
    %{order: 35, title: "Tradition", words: ["伝統", "文化", "風習", "歴史", "遺産"]},
    %{order: 36, title: "Language", words: ["言語", "方言", "語学", "翻訳", "意味"]}
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    n5_only = "--n5" in args
    n4_only = "--n4" in args
    n3_only = "--n3" in args

    Logger.info("=" |> String.duplicate(60))
    Logger.info("v9 Curated Lesson Generator")
    Logger.info("=" |> String.duplicate(60))

    cond do
      n5_only ->
        Logger.info("\nGenerating N5 lessons only...\n")
        generate_n5()

      n4_only ->
        Logger.info("\nGenerating N4 lessons only...\n")
        generate_n4()

      n3_only ->
        Logger.info("\nGenerating N3 lessons only...\n")
        generate_n3()

      true ->
        Logger.info("\nGenerating all levels (N5, N4, N3)...\n")
        generate_n5()
        generate_n4()
        generate_n3()
    end

    Logger.info("=" |> String.duplicate(60))
    Logger.info("Complete!")
    Logger.info("=" |> String.duplicate(60))
  end

  defp generate_n5 do
    Logger.info("\n📚 Generating N5 Curriculum (#{length(@n5_curriculum)} lessons)...")
    delete_existing_lessons(5)

    created =
      Enum.reduce(@n5_curriculum, [], fn lesson_def, acc ->
        case create_lesson(lesson_def, 5) do
          {:ok, lesson} ->
            [lesson | acc]

          {:error, reason} ->
            Logger.error("Failed: #{inspect(reason)}")
            acc
        end
      end)
      |> Enum.reverse()

    Logger.info("✅ Created #{length(created)} N5 lessons")
  end

  defp generate_n4 do
    Logger.info("\n📚 Generating N4 Curriculum (#{length(@n4_curriculum)} lessons)...")
    delete_existing_lessons(4)

    created =
      Enum.reduce(@n4_curriculum, [], fn lesson_def, acc ->
        case create_lesson(lesson_def, 4) do
          {:ok, lesson} ->
            [lesson | acc]

          {:error, reason} ->
            Logger.error("Failed: #{inspect(reason)}")
            acc
        end
      end)
      |> Enum.reverse()

    Logger.info("✅ Created #{length(created)} N4 lessons")
  end

  defp generate_n3 do
    Logger.info("\n📚 Generating N3 Curriculum (#{length(@n3_curriculum)} lessons)...")
    delete_existing_lessons(3)

    created =
      Enum.reduce(@n3_curriculum, [], fn lesson_def, acc ->
        case create_lesson(lesson_def, 3) do
          {:ok, lesson} ->
            [lesson | acc]

          {:error, reason} ->
            Logger.error("Failed: #{inspect(reason)}")
            acc
        end
      end)
      |> Enum.reverse()

    Logger.info("✅ Created #{length(created)} N3 lessons")
  end

  defp create_lesson(lesson_def, difficulty) do
    level =
      case difficulty do
        5 -> "N5"
        4 -> "N4"
        3 -> "N3"
        _ -> "N?"
      end

    title = "#{lesson_def.order}. #{lesson_def.title}"

    # Find words in database
    word_ids =
      Enum.reduce(lesson_def.words, [], fn word_text, acc ->
        case find_word(word_text) do
          nil ->
            Logger.warning("  Word not found: #{word_text}")
            acc

          word ->
            [word.id | acc]
        end
      end)
      |> Enum.reverse()

    if length(word_ids) == 0 do
      {:error, "No words found"}
    else
      attrs = %{
        title: title,
        description:
          "#{level} Lesson #{lesson_def.order}: #{lesson_def.title}. Learn #{length(word_ids)} essential words.",
        difficulty: difficulty,
        order_index: lesson_def.order * 100,
        lesson_type: :reading
      }

      links =
        Enum.with_index(word_ids, fn word_id, idx ->
          %{word_id: word_id, position: idx}
        end)

      case Content.create_lesson_with_words(attrs, links) do
        {:ok, lesson} ->
          Logger.info("  ✅ #{title} (#{length(word_ids)} words)")

          case Tests.generate_lesson_test(lesson.id) do
            {:ok, _} -> :ok
            {:error, reason} -> Logger.warning("    Test: #{inspect(reason)}")
          end

          {:ok, lesson}

        {:error, changeset} ->
          {:error, changeset.errors}
      end
    end
  end

  defp find_word(text) do
    # Try exact text match first
    word = Repo.one(from w in Word, where: w.text == ^text, limit: 1)

    if word do
      word
    else
      # Try reading match (for expressions)
      Repo.one(
        from w in Word,
          where: w.reading == ^text,
          order_by: w.core_rank,
          limit: 1
      )
    end
  end

  defp delete_existing_lessons(difficulty) do
    level =
      case difficulty do
        5 -> "N5"
        4 -> "N4"
        3 -> "N3"
        _ -> "N?"
      end

    Logger.info("🗑️  Cleaning up existing #{level} lessons...")

    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM lesson_words WHERE lesson_id IN (SELECT id FROM lessons WHERE difficulty = #{difficulty})"
    )

    Ecto.Adapters.SQL.query!(Repo, "DELETE FROM lessons WHERE difficulty = #{difficulty}")

    Logger.info("   Done!")
  end
end
