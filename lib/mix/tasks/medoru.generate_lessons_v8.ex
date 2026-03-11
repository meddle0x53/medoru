defmodule Mix.Tasks.Medoru.GenerateLessonsV8 do
  @moduledoc """
  Generate pedagogically sound N5 lessons with gradual progression.

  Each lesson has 4-5 carefully selected words following a proper curriculum.

  ## Examples

      mix medoru.generate_lessons_v8 [--dry-run]

  """
  use Mix.Task
  require Logger

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Lesson, LessonWord, Word}
  alias Medoru.Tests

  @requirements ["app.start"]

  # Curriculum: 40 progressive lessons for N5
  @lesson_definitions [
    # === PHASE 1: ABSOLUTE BASICS (Lessons 1-5) ===
    %{order: 1, title: "Numbers 1-5", topic: :numbers, count: 5},
    %{order: 2, title: "Numbers 6-10", topic: :numbers, count: 5},
    %{order: 3, title: "Greetings", topic: :greetings, count: 5},
    %{order: 4, title: "Self-Introduction", topic: :self_intro, count: 5},
    %{order: 5, title: "Basic Pronouns", topic: :pronouns, count: 5},

    # === PHASE 2: FAMILY & PEOPLE (Lessons 6-8) ===
    %{order: 6, title: "Family Members", topic: :family, count: 5},
    %{order: 7, title: "People & Titles", topic: :people, count: 5},
    %{order: 8, title: "Occupations", topic: :occupations, count: 5},

    # === PHASE 3: TIME (Lessons 9-12) ===
    %{order: 9, title: "Days of the Week", topic: :days, count: 5},
    %{order: 10, title: "Time of Day", topic: :time, count: 5},
    %{order: 11, title: "Calendar", topic: :calendar, count: 5},
    %{order: 12, title: "Time Expressions", topic: :time_exp, count: 5},

    # === PHASE 4: CORE VERBS (Lessons 13-17) ===
    %{order: 13, title: "Being & Existing", topic: :be_verbs, count: 5},
    %{order: 14, title: "Movement: Go & Come", topic: :move_verbs, count: 5},
    %{order: 15, title: "Actions: Eat & Drink", topic: :eat_verbs, count: 5},
    %{order: 16, title: "Actions: See & Do", topic: :action_verbs, count: 5},
    %{order: 17, title: "Daily Activities", topic: :daily_verbs, count: 5},

    # === PHASE 5: FOOD & DRINK (Lessons 18-20) ===
    %{order: 18, title: "Food 1: Staples", topic: :food1, count: 5},
    %{order: 19, title: "Food 2: Dishes", topic: :food2, count: 5},
    %{order: 20, title: "Drinks", topic: :drinks, count: 5},

    # === PHASE 6: PLACES (Lessons 21-24) ===
    %{order: 21, title: "Home & Rooms", topic: :home, count: 5},
    %{order: 22, title: "School & Work", topic: :school, count: 5},
    %{order: 23, title: "Transportation", topic: :transport, count: 5},
    %{order: 24, title: "Places in Town", topic: :places, count: 5},

    # === PHASE 7: ADJECTIVES (Lessons 25-28) ===
    %{order: 25, title: "Sizes & Shapes", topic: :size_adj, count: 5},
    %{order: 26, title: "Qualities: Good & Bad", topic: :quality_adj, count: 5},
    %{order: 27, title: "Feelings", topic: :feeling_adj, count: 5},
    %{order: 28, title: "Colors", topic: :colors, count: 5},

    # === PHASE 8: SHOPPING & MONEY (Lessons 29-31) ===
    %{order: 29, title: "Shopping", topic: :shopping, count: 5},
    %{order: 30, title: "Money", topic: :money, count: 5},
    %{order: 31, title: "Numbers 11-100", topic: :numbers_big, count: 5},

    # === PHASE 9: NATURE (Lessons 32-34) ===
    %{order: 32, title: "Weather", topic: :weather, count: 5},
    %{order: 33, title: "Nature", topic: :nature, count: 5},
    %{order: 34, title: "Animals", topic: :animals, count: 5},

    # === PHASE 10: BODY & HEALTH (Lessons 35-36) ===
    %{order: 35, title: "Body Parts", topic: :body, count: 5},
    %{order: 36, title: "Health", topic: :health, count: 5},

    # === PHASE 11: CLOTHING & ITEMS (Lessons 37-38) ===
    %{order: 37, title: "Clothing", topic: :clothing, count: 5},
    %{order: 38, title: "Daily Items", topic: :items, count: 5},

    # === PHASE 12: ADVANCED TOPICS (Lessons 39-42) ===
    %{order: 39, title: "Directions", topic: :directions, count: 5},
    %{order: 40, title: "Hobbies", topic: :hobbies, count: 5},
    %{order: 41, title: "Travel", topic: :travel, count: 5},
    %{order: 42, title: "Emotions", topic: :emotions, count: 5}
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    dry_run = "--dry-run" in args

    Logger.info("=" |> String.duplicate(60))
    Logger.info("v8 Pedagogical N5 Lesson Generator")
    Logger.info("=" |> String.duplicate(60))

    if dry_run do
      Logger.info("\n🔍 DRY RUN MODE - No database changes\n")
    end

    unless dry_run do
      IO.puts("\n⚠️  This will DELETE all existing N5 lessons and create 42 new pedagogical ones!")
      IO.puts("Each lesson has 4-5 carefully selected words.")
      IO.puts("Type 'yes' to continue:")

      case IO.gets("") |> String.trim() do
        "yes" ->
          :ok

        _ ->
          IO.puts("Aborted.")
          exit(:normal)
      end
    end

    # Load and categorize all N5 words
    words_by_topic = load_and_categorize_words()

    total_available =
      words_by_topic
      |> Map.values()
      |> List.flatten()
      |> length()

    Logger.info("Categorized #{total_available} unique N5 words by topic")

    # Generate lessons
    lessons = generate_lessons(words_by_topic, dry_run)

    Logger.info("=" |> String.duplicate(60))
    Logger.info("Generation Complete!")
    Logger.info("Created #{length(lessons)} lessons")
    Logger.info("=" |> String.duplicate(60))

    unless dry_run do
      show_samples()
    end
  end

  defp load_and_categorize_words do
    words =
      Word
      |> where(difficulty: 5)
      |> Repo.all()

    # Categorize each word by topic based on meaning/text
    Enum.reduce(words, %{}, fn word, acc ->
      topics = categorize_word(word)

      Enum.reduce(topics, acc, fn topic, acc2 ->
        Map.update(acc2, topic, [word], fn list -> [word | list] end)
      end)
    end)
    |> Enum.map(fn {topic, words} ->
      # Remove duplicates and sort by frequency
      unique = Enum.uniq_by(words, & &1.id)
      # Sort by core_rank (lower = more common/core words)
      sorted = Enum.sort_by(unique, &(&1.core_rank || 9999))
      {topic, sorted}
    end)
    |> Enum.into(%{})
  end

  defp categorize_word(word) do
    text = String.downcase(word.text)
    meaning = String.downcase(word.meaning || "")
    combined = text <> " " <> meaning

    topics = []

    # Numbers
    topics = if is_number_word?(combined), do: [:numbers, :numbers_big | topics], else: topics

    # Greetings
    topics =
      if matches?(combined, [
           "hello",
           "goodbye",
           "morning",
           "evening",
           "night",
           "greeting",
           "hi ",
           "bye"
         ]), do: [:greetings | topics], else: topics

    # Self intro
    topics =
      if matches?(combined, ["name", "call", "self", "introduction", "nice to meet", "pleased"]),
        do: [:self_intro | topics],
        else: topics

    # Pronouns
    topics =
      if matches?(combined, [
           "watashi",
           "boku",
           "anata",
           "kare",
           "kanojo",
           "i ",
           "you",
           "he ",
           "she "
         ]), do: [:pronouns | topics], else: topics

    # Family
    topics =
      if matches?(combined, [
           "father",
           "mother",
           "parent",
           "brother",
           "sister",
           "family",
           "child",
           "son",
           "daughter"
         ]), do: [:family | topics], else: topics

    # People/Occupations
    topics =
      if matches?(combined, [
           "person",
           "people",
           "teacher",
           "student",
           "doctor",
           "worker",
           "company"
         ]), do: [:people, :occupations | topics], else: topics

    # Days/Time
    topics =
      if matches?(combined, [
           "monday",
           "tuesday",
           "wednesday",
           "thursday",
           "friday",
           "saturday",
           "sunday",
           "week"
         ]), do: [:days | topics], else: topics

    topics =
      if matches?(combined, [
           "hour",
           "minute",
           "time",
           "o'clock",
           "half",
           "am",
           "pm",
           "morning",
           "evening",
           "noon"
         ]), do: [:time | topics], else: topics

    topics =
      if matches?(combined, [
           "january",
           "february",
           "march",
           "month",
           "year",
           "date",
           "calendar",
           "birthday"
         ]), do: [:calendar | topics], else: topics

    topics =
      if matches?(combined, [
           "today",
           "tomorrow",
           "yesterday",
           "day before",
           "day after",
           "last week",
           "next week"
         ]), do: [:time_exp | topics], else: topics

    # Verbs
    topics =
      if matches?(combined, ["desu", "is ", "am ", "are "]) and word.word_type == "expression",
        do: [:be_verbs | topics],
        else: topics

    topics =
      if matches?(combined, ["go", "come", "return", "arrive", "leave"]) and
           word.word_type == "verb", do: [:move_verbs | topics], else: topics

    topics =
      if matches?(combined, ["eat", "drink", "tabemasu", "nomimasu"]) and word.word_type == "verb",
        do: [:eat_verbs | topics],
        else: topics

    topics =
      if matches?(combined, ["see", "look", "watch", "read", "write", "speak", "say", "hear"]) and
           word.word_type == "verb", do: [:action_verbs | topics], else: topics

    topics =
      if matches?(combined, ["do", "make", "take", "give", "receive", "use"]) and
           word.word_type == "verb", do: [:daily_verbs | topics], else: topics

    # Food
    topics =
      if matches?(combined, [
           "rice",
           "bread",
           "noodle",
           "meat",
           "fish",
           "vegetable",
           "fruit",
           "food"
         ]), do: [:food1, :food2 | topics], else: topics

    topics =
      if matches?(combined, ["sushi", "tempura", "curry", "soup", "salad", "dish", "meal"]),
        do: [:food2 | topics],
        else: topics

    topics =
      if matches?(combined, [
           "water",
           "tea",
           "coffee",
           "juice",
           "milk",
           "drink",
           "beer",
           "sake",
           "alcohol"
         ]), do: [:drinks | topics], else: topics

    # Places
    topics =
      if matches?(combined, [
           "house",
           "home",
           "room",
           "kitchen",
           "bedroom",
           "bathroom",
           "door",
           "window"
         ]), do: [:home | topics], else: topics

    topics =
      if matches?(combined, [
           "school",
           "teacher",
           "student",
           "class",
           "lesson",
           "study",
           "learn",
           "book"
         ]), do: [:school | topics], else: topics

    topics =
      if matches?(combined, ["train", "bus", "car", "bicycle", "station", "airport", "transport"]),
         do: [:transport | topics],
         else: topics

    topics =
      if matches?(combined, [
           "store",
           "shop",
           "restaurant",
           "hospital",
           "bank",
           "park",
           "building",
           "place"
         ]), do: [:places | topics], else: topics

    # Adjectives
    topics =
      if matches?(combined, [
           "big",
           "small",
           "long",
           "short",
           "tall",
           "round",
           "square",
           "size",
           "shape"
         ]) and word.word_type == "adjective", do: [:size_adj | topics], else: topics

    topics =
      if matches?(combined, ["good", "bad", "new", "old", "young"]) and
           word.word_type == "adjective", do: [:quality_adj | topics], else: topics

    topics =
      if matches?(combined, ["happy", "sad", "fun", "interesting", "tasty", "delicious", "boring"]) and
           word.word_type == "adjective", do: [:feeling_adj | topics], else: topics

    topics =
      if matches?(combined, [
           "red",
           "blue",
           "white",
           "black",
           "green",
           "yellow",
           "color",
           "colour"
         ]), do: [:colors | topics], else: topics

    # Shopping/Money
    topics =
      if matches?(combined, ["buy", "sell", "shop", "shopping", "store", "pay"]),
        do: [:shopping | topics],
        else: topics

    topics =
      if matches?(combined, [
           "money",
           "yen",
           "dollar",
           "cheap",
           "expensive",
           "price",
           "cost",
           "free"
         ]), do: [:money | topics], else: topics

    # Nature
    topics =
      if matches?(combined, [
           "weather",
           "rain",
           "snow",
           "sun",
           "cloud",
           "wind",
           "hot",
           "cold",
           "warm",
           "cool"
         ]), do: [:weather | topics], else: topics

    topics =
      if matches?(combined, [
           "mountain",
           "river",
           "sea",
           "ocean",
           "tree",
           "flower",
           "forest",
           "nature"
         ]), do: [:nature | topics], else: topics

    topics =
      if matches?(combined, ["dog", "cat", "bird", "fish", "animal", "pet"]),
        do: [:animals | topics],
        else: topics

    # Body/Health
    topics =
      if matches?(combined, [
           "head",
           "face",
           "eye",
           "ear",
           "nose",
           "mouth",
           "hand",
           "foot",
           "body",
           "leg",
           "arm"
         ]), do: [:body | topics], else: topics

    topics =
      if matches?(combined, [
           "health",
           "sick",
           "ill",
           "medicine",
           "doctor",
           "hospital",
           "pain",
           "hurt"
         ]), do: [:health | topics], else: topics

    # Clothing
    topics =
      if matches?(combined, [
           "shirt",
           "pants",
           "dress",
           "skirt",
           "shoe",
           "hat",
           "clothes",
           "wear",
           "sock"
         ]), do: [:clothing | topics], else: topics

    # Items
    topics =
      if matches?(combined, [
           "phone",
           "computer",
           "bag",
           "key",
           "wallet",
           "watch",
           "clock",
           "umbrella"
         ]), do: [:items | topics], else: topics

    # Directions
    topics =
      if matches?(combined, [
           "right",
           "left",
           "straight",
           "turn",
           "direction",
           "north",
           "south",
           "east",
           "west"
         ]), do: [:directions | topics], else: topics

    # Hobbies
    topics =
      if matches?(combined, [
           "hobby",
           "sport",
           "music",
           "movie",
           "game",
           "play",
           "read",
           "dance",
           "sing"
         ]), do: [:hobbies | topics], else: topics

    # Travel
    topics =
      if matches?(combined, [
           "travel",
           "trip",
           "hotel",
           "passport",
           "luggage",
           "sightseeing",
           "foreign",
           "abroad"
         ]), do: [:travel | topics], else: topics

    # Emotions
    topics =
      if matches?(combined, ["like", "love", "hate", "want", "need", "think", "feel", "emotion"]),
        do: [:emotions | topics],
        else: topics

    # Default: if no topics matched, it's a general word
    if topics == [], do: [:general], else: topics
  end

  defp is_number_word?(text) do
    number_patterns = [
      "one",
      "two",
      "three",
      "four",
      "five",
      "six",
      "seven",
      "eight",
      "nine",
      "ten",
      "eleven",
      "twelve",
      "thirteen",
      "fourteen",
      "fifteen",
      "sixteen",
      "seventeen",
      "eighteen",
      "nineteen",
      "twenty",
      "thirty",
      "forty",
      "fifty",
      "sixty",
      "seventy",
      "eighty",
      "ninety",
      "hundred",
      "thousand",
      "million"
    ]

    matches?(text, number_patterns)
  end

  defp matches?(text, patterns) do
    Enum.any?(patterns, fn pattern ->
      String.contains?(text, pattern)
    end)
  end

  defp generate_lessons(words_by_topic, dry_run) do
    unless dry_run do
      delete_existing_n5_lessons()
    end

    used_ids = MapSet.new()

    Enum.reduce(@lesson_definitions, {[], used_ids}, fn def, {acc, used} ->
      if dry_run do
        available = Map.get(words_by_topic, def.topic, [])
        remaining = Enum.reject(available, fn w -> MapSet.member?(used, w.id) end)
        selected = Enum.take(remaining, def.count)

        Logger.info("Lesson #{def.order}: #{def.title}")

        Logger.info(
          "  Topic: #{def.topic}, Available: #{length(available)}, New: #{length(selected)}"
        )

        new_used = MapSet.union(used, MapSet.new(Enum.map(selected, & &1.id)))
        {[def | acc], new_used}
      else
        {lesson, new_used} = create_lesson(def, words_by_topic, used)
        {[lesson | acc], new_used}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.reject(&is_nil/1)
  end

  defp create_lesson(def, words_by_topic, used_ids) do
    title = "#{def.order}. #{def.title}"

    # Get available words for this topic
    available = Map.get(words_by_topic, def.topic, [])

    # Filter out already used words
    remaining = Enum.reject(available, fn w -> MapSet.member?(used_ids, w.id) end)

    # Select words for this lesson
    selected = Enum.take(remaining, def.count)

    if length(selected) == 0 do
      Logger.warning("⚠️  #{title}: No words available for topic #{def.topic}")
      {nil, used_ids}
    else
      # Create lesson
      attrs = %{
        title: title,
        description:
          "N5 Lesson #{def.order}: #{def.title}. Learn #{length(selected)} new words about #{def.topic}.",
        difficulty: 5,
        order_index: def.order * 100,
        lesson_type: :reading
      }

      links =
        Enum.with_index(selected, fn word, idx ->
          %{word_id: word.id, position: idx}
        end)

      case Content.create_lesson_with_words(attrs, links) do
        {:ok, lesson} ->
          Logger.info("✅ #{title}: #{length(selected)} words")

          # Generate test
          case Tests.generate_lesson_test(lesson.id) do
            {:ok, _} -> :ok
            {:error, reason} -> Logger.warning("  Test: #{inspect(reason)}")
          end

          new_used = MapSet.union(used_ids, MapSet.new(Enum.map(selected, & &1.id)))
          {lesson, new_used}

        {:error, changeset} ->
          Logger.error("❌ #{title}: #{inspect(changeset.errors)}")
          {nil, used_ids}
      end
    end
  end

  defp delete_existing_n5_lessons do
    Logger.info("🗑️  Deleting existing N5 lessons...")

    # Use raw SQL for cascade delete
    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM lesson_words WHERE lesson_id IN (SELECT id FROM lessons WHERE difficulty = 5)"
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM lesson_progress WHERE lesson_id IN (SELECT id FROM lessons WHERE difficulty = 5)"
    )

    result = Ecto.Adapters.SQL.query!(Repo, "DELETE FROM lessons WHERE difficulty = 5")

    Logger.info("   Deleted #{result.num_rows} lessons")
  end

  defp show_samples do
    Logger.info("\n📚 Sample Lessons:")

    Lesson
    |> where(difficulty: 5)
    |> limit(8)
    |> order_by([l], l.order_index)
    |> Repo.all()
    |> Enum.each(fn lesson ->
      count =
        Repo.aggregate(from(lw in LessonWord, where: lw.lesson_id == ^lesson.id), :count, :id)

      Logger.info("  #{lesson.title} - #{count} words")
    end)
  end
end
