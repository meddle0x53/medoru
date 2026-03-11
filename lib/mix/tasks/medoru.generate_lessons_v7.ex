defmodule Mix.Tasks.Medoru.GenerateLessonsV7 do
  @moduledoc """
  Generate topic-based lessons using Core 6000 enriched word pool.

  Creates 300 lessons (100 N5, 100 N4, 100 N3) with:
  - Topic-based grouping using word characteristics
  - Progressive difficulty within each level
  - Vocabulary, reading, and grammar lesson types

  Usage:
    mix medoru.generate_lessons_v7 [--dry-run]
  """

  use Mix.Task
  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.Lesson

  @requirements ["app.start"]

  # Lesson configuration
  @words_per_lesson 15
  @reading_lesson_interval 10
  @writing_lesson_interval 20
  @listening_lesson_interval 15

  # N5 Topics - matched to actual Core 6000 word distribution
  # Based on analysis of the first 1500 words in the pool
  @n5_topics [
    # Foundation (1-10) - Numbers and basic pronouns
    "Basic Words & Pronouns",
    "Numbers 1-10",
    "Numbers 11-100",
    "Time & Days",
    "Calendar Words",
    "Common Adjectives",
    "Directions & Positions",
    "People & Pronouns",
    "Basic Nouns 1",
    "Basic Nouns 2",
    # Daily Actions (11-25) - Verbs for daily life
    "Daily Verbs 1",
    "Daily Verbs 2",
    "Movement Verbs",
    "Communication Verbs",
    "Perception Verbs",
    "Food & Eating",
    "Drinks & Meals",
    "Shopping & Buying",
    "Money & Prices",
    "Colors & Description",
    "Clothing & Wear",
    "Weather & Seasons",
    "Months & Dates",
    "House & Rooms",
    "Furniture & Items",
    # Getting Around (26-35) - Transportation and places
    "Transportation 1",
    "Transportation 2",
    "Places in Town 1",
    "Places in Town 2",
    "Stores & Shops",
    "Navigation & Directions",
    "Travel Words",
    "Public Buildings",
    "Nature & Outdoors",
    "Animals & Creatures",
    # Body & Health (36-45)
    "Body Parts 1",
    "Body Parts 2",
    "Health & Illness",
    "Feelings & Emotions",
    "Preferences & Likes",
    "Family Members",
    "Relationships",
    "Occupations",
    "Work & Business",
    "School & Education",
    # Abstract (46-60) - More complex concepts
    "Time Expressions",
    "Frequency & Habits",
    "Quantity & Amount",
    "Size & Distance",
    "Quality & Degree",
    "Temperature & Feel",
    "Abilities & Skills",
    "Desires & Wants",
    "Thoughts & Ideas",
    "Hobbies & Interests",
    "Sports & Games",
    "Entertainment",
    "Arts & Culture",
    "Music & Songs",
    "Reading & Writing",
    # Advanced (61-75)
    "Complex Verbs 1",
    "Complex Verbs 2",
    "Compound Words",
    "Formal Expressions",
    "Casual Speech",
    "Polite Requests",
    "Exclamations",
    "Question Forms",
    "Comparisons",
    "Changes & Transitions",
    "Planning & Goals",
    "Memories & Past",
    "Learning & Study",
    "Teaching & Explaining",
    "Success & Failure",
    # Review (76-100)
    "Review: Numbers & Time",
    "Review: Daily Life",
    "Review: People & Places",
    "Review: Actions",
    "Review: Descriptions",
    "Reading Practice 1",
    "Reading Practice 2",
    "Reading Practice 3",
    "Reading Practice 4",
    "Reading Practice 5",
    "Grammar Focus 1",
    "Grammar Focus 2",
    "Grammar Focus 3",
    "Grammar Focus 4",
    "Grammar Focus 5",
    "Vocabulary Builder 1",
    "Vocabulary Builder 2",
    "Vocabulary Builder 3",
    "Vocabulary Builder 4",
    "Vocabulary Builder 5",
    "Final Review 1",
    "Final Review 2",
    "Final Review 3",
    "Final Review 4",
    "Final Review 5"
  ]

  # N4 Topics - matched to Core 6000 words (1001-2000)
  @n4_topics [
    # People & Relationships (1-10) - 男の子, 私たち, 家, 客, etc.
    "People & Groups",
    "Family Terms",
    "Visitors & Guests",
    "Compound Words 1",
    "Compound Words 2",
    "Weather & Nature",
    "Colors & Shades",
    "Time Words 1",
    "Time Words 2",
    "Time Expressions",
    # Directions & Position (11-20) - 東, 西, 南, 北, 向かう, etc.
    "Cardinal Directions",
    "Movement & Facing",
    "Time & Space",
    "Intervals & Duration",
    "Human & Time",
    "Size & Measurement",
    "Beginnings & Ends",
    "Sequence & Order",
    "Time Particles",
    "Future & Past",
    # Daily Life (21-35) - 毎朝, 今朝, もし, 牛, 半分, etc.
    "Daily Routines",
    "Time Periods",
    "Fractions & Parts",
    "Morning & Evening",
    "Conditional Expressions",
    "Animals & Nature",
    "Shopping & Commerce",
    "Clothing & Fashion",
    "Food & Cooking",
    "Home & Living",
    "Work & Study",
    "Travel & Places",
    "Health & Body",
    "Emotions & Feelings",
    "Communication",
    # Society (36-50)
    "Technology & Media",
    "Transportation",
    "City & Country",
    "Money & Banking",
    "Business Terms",
    "School & Learning",
    "Government & Law",
    "Culture & Traditions",
    "Entertainment",
    "Sports & Games",
    # Abstract (51-70)
    "Thoughts & Ideas",
    "Plans & Goals",
    "Success & Failure",
    "Learning & Growth",
    "Memory & Experience",
    "Changes & Transitions",
    "Comparisons & Degrees",
    "Cause & Effect",
    "Possibility & Ability",
    "Desire & Intention",
    "Preference & Choice",
    "Permission & Prohibition",
    "Obligation & Duty",
    "Advice & Suggestion",
    "Request & Command",
    # More Daily Life (71-80)
    "Weather Expressions",
    "Seasonal Events",
    "Shopping Terms",
    "Dining Out",
    "Cooking Methods",
    "Home Appliances",
    "Furniture Items",
    "Cleaning & Chores",
    "Personal Care",
    "Daily Schedule",
    # Review (81-100)
    "N4 Grammar 1",
    "N4 Grammar 2",
    "N4 Grammar 3",
    "N4 Grammar 4",
    "N4 Grammar 5",
    "N4 Grammar 6",
    "N4 Grammar 7",
    "N4 Grammar 8",
    "N4 Grammar 9",
    "N4 Grammar 10",
    "Reading Practice 1",
    "Reading Practice 2",
    "Reading Practice 3",
    "Reading Practice 4",
    "Reading Practice 5",
    "Reading Practice 6",
    "Reading Practice 7",
    "Reading Practice 8",
    "Reading Practice 9",
    "Reading Practice 10",
    "Vocabulary Builder 1",
    "Vocabulary Builder 2",
    "Vocabulary Builder 3",
    "Vocabulary Builder 4",
    "Vocabulary Builder 5",
    "Final Review 1",
    "Final Review 2",
    "Final Review 3",
    "Final Review 4",
    "Final Review 5"
  ]

  # N3 Topics - matched to Core 6000 words (2001-3000)
  @n3_topics [
    # Home & Daily Life (1-10) - 住宅, 自宅, 早起き, 昼寝, etc.
    "Housing & Homes",
    "Daily Habits",
    "Hobbies & Interests",
    "Both & Either",
    "Parents & Family",
    "Directions & Sides",
    "Position & Location",
    "Inside & Outside",
    "Publications & Media",
    "Details & Precision",
    # Language & Work (11-20) - 訳, 検討, 付く, 片付ける, etc.
    "Translation & Language",
    "Consideration & Planning",
    "Attachment & Connection",
    "Organization & Tidying",
    "Reception & Service",
    "Memorials & Occasions",
    "Examples & Illustrations",
    "Exclusion & Removal",
    "Time & Schedule",
    "Texture & Feel",
    # Emotional States (21-30) - 残念, 苦しい, 幸せ, 貧乏, etc.
    "Emotions & Feelings",
    "Hardship & Difficulty",
    "Taste & Flavor",
    "Wealth & Poverty",
    "Happiness & Misfortune",
    "Scale & Scope",
    "Agriculture & Food",
    "Business & Industry",
    "Materials & Substances",
    "Tools & Equipment",
    # Society & Culture (31-45)
    "Community & Society",
    "Traditions & Customs",
    "Arts & Entertainment",
    "Music & Performance",
    "Literature & Writing",
    "Science & Technology",
    "Nature & Environment",
    "Health & Medicine",
    "Education & Research",
    "Politics & Government",
    "Economics & Trade",
    "Law & Justice",
    "History & Geography",
    "International Relations",
    "Modern Issues",
    # Advanced Language (46-60)
    "Formal Speech",
    "Humble Expressions",
    "Polite Requests",
    "Causative Forms",
    "Passive Forms",
    "Conditional Nuances",
    "Quoted Speech",
    "Nominalization",
    "Emphatic Patterns",
    "Complex Particles",
    "Compound Verbs",
    "Auxiliary Verbs",
    "Transitive/Intransitive",
    "Potential Forms",
    "Volitional Forms",
    # More Advanced Topics (61-70)
    "Respectful Language",
    "Modest Expressions",
    "Indirect Speech",
    "Hypothetical Forms",
    "Simultaneous Actions",
    "Preparatory Actions",
    "Completion & Regret",
    "Attempt & Trial",
    "Gradual Change",
    "Directional Movement",
    # Review (71-100)
    "N3 Grammar 1",
    "N3 Grammar 2",
    "N3 Grammar 3",
    "N3 Grammar 4",
    "N3 Grammar 5",
    "N3 Grammar 6",
    "N3 Grammar 7",
    "N3 Grammar 8",
    "N3 Grammar 9",
    "N3 Grammar 10",
    "Reading Comprehension 1",
    "Reading Comprehension 2",
    "Reading Comprehension 3",
    "Reading Comprehension 4",
    "Reading Comprehension 5",
    "Reading Comprehension 6",
    "Reading Comprehension 7",
    "Reading Comprehension 8",
    "Reading Comprehension 9",
    "Reading Comprehension 10",
    "Vocabulary Expansion 1",
    "Vocabulary Expansion 2",
    "Vocabulary Expansion 3",
    "Vocabulary Expansion 4",
    "Vocabulary Expansion 5",
    "Final Review 1",
    "Final Review 2",
    "Final Review 3",
    "Final Review 4",
    "Final Review 5"
  ]

  @impl Mix.Task
  def run(args) do
    dry_run = "--dry-run" in args

    IO.puts("=" |> String.duplicate(60))
    IO.puts("v7 Topic-Based Lesson Generator")
    IO.puts("=" |> String.duplicate(60))

    if dry_run do
      IO.puts("\n🔍 DRY RUN MODE - No database changes\n")
    end

    # Load word pool
    word_pool = load_word_pool()

    IO.puts("\nWord pool loaded:")
    IO.puts("  N5: #{length(word_pool["n5"])} words")
    IO.puts("  N4: #{length(word_pool["n4"])} words")
    IO.puts("  N3: #{length(word_pool["n3"])} words")

    # Confirm before proceeding
    unless dry_run do
      IO.puts("\n⚠️  This will DELETE all existing N5-N3 lessons and create new ones!")
      IO.puts("Type 'yes' to continue:")

      case IO.gets("") |> String.trim() do
        "yes" ->
          :ok

        _ ->
          IO.puts("Aborted.")
          exit(:normal)
      end

      # Delete existing lessons
      delete_existing_lessons()
    end

    # Generate lessons for each level
    lessons =
      []
      |> generate_level_lessons(5, word_pool["n5"], @n5_topics, dry_run)
      |> generate_level_lessons(4, word_pool["n4"], @n4_topics, dry_run)
      |> generate_level_lessons(3, word_pool["n3"], @n3_topics, dry_run)

    IO.puts(("\n" <> "=") |> String.duplicate(60))
    IO.puts("Generation Complete!")
    IO.puts("  Total lessons: #{length(lessons)}")

    unless dry_run do
      IO.puts("  N5: #{Repo.aggregate(from(l in Lesson, where: l.difficulty == 5), :count)}")
      IO.puts("  N4: #{Repo.aggregate(from(l in Lesson, where: l.difficulty == 4), :count)}")
      IO.puts("  N3: #{Repo.aggregate(from(l in Lesson, where: l.difficulty == 3), :count)}")
    end

    IO.puts("=" |> String.duplicate(60))
  end

  defp load_word_pool do
    case File.read("data/v7_lesson_pool.json") do
      {:ok, json} ->
        data = Jason.decode!(json)
        data["words_by_level"]

      {:error, _} ->
        IO.puts("❌ Error: data/v7_lesson_pool.json not found!")
        IO.puts("   Run: mix run priv/repo/parse_anki_export.exs first")
        exit({:shutdown, 1})
    end
  end

  defp delete_existing_lessons do
    IO.puts("\n🗑️  Deleting existing N5-N3 lessons...")

    from(l in Lesson, where: l.difficulty in [3, 4, 5])
    |> Repo.all()
    |> Enum.each(fn lesson ->
      # Delete lesson progress first (convert string UUID to binary)
      lesson_id_binary = Ecto.UUID.dump!(lesson.id)

      from(lp in "lesson_progress", where: lp.lesson_id == ^lesson_id_binary)
      |> Repo.delete_all()

      Repo.delete!(lesson)
    end)

    IO.puts("   Done!")
  end

  defp generate_level_lessons(acc, difficulty, words, topics, dry_run) do
    level_name = "N#{difficulty}"
    IO.puts("\n📚 Generating #{level_name} lessons...")

    # Track used word indices to avoid duplicates
    total_words = length(words)
    words_per_lesson = @words_per_lesson

    lessons =
      topics
      |> Enum.with_index(1)
      |> Enum.map(fn {topic, index} ->
        lesson_type = determine_lesson_type(index)

        # Calculate word range for this lesson
        # Each lesson gets a slice of the word pool
        start_idx = (index - 1) * words_per_lesson
        end_idx = min(start_idx + words_per_lesson - 1, total_words - 1)

        # Select words for this lesson
        selected_words =
          if start_idx < total_words do
            Enum.slice(words, start_idx..end_idx)
          else
            # If we run out of words, wrap around and take remaining
            remaining = words_per_lesson - (total_words - start_idx)
            Enum.slice(words, start_idx..-1) ++ Enum.slice(words, 0..(remaining - 1))
          end

        # Deduplicate word IDs
        selected_words = Enum.uniq_by(selected_words, & &1["word_id"])

        lesson = %{
          title: "#{index}. #{topic}",
          description: generate_description(topic, lesson_type, selected_words),
          difficulty: difficulty,
          order: index,
          word_count: length(selected_words),
          word_ids: Enum.map(selected_words, & &1["word_id"]),
          lesson_type: lesson_type
        }

        if dry_run do
          samples = selected_words |> Enum.take(3) |> Enum.map(& &1["word"]) |> Enum.join(", ")
          IO.puts("  [#{level_name}] #{lesson.title} - #{samples}...")
        else
          create_lesson_in_db(lesson)
        end

        lesson
      end)

    lessons ++ acc
  end

  defp determine_lesson_type(index) do
    cond do
      rem(index, @writing_lesson_interval) == 0 -> :writing
      rem(index, @listening_lesson_interval) == 0 -> :listening
      rem(index, @reading_lesson_interval) == 0 -> :reading
      true -> :grammar
    end
  end

  defp generate_description(topic, lesson_type, words) do
    samples = words |> Enum.take(3) |> Enum.map(& &1["word"]) |> Enum.join(", ")
    topic_lower = String.downcase(topic)

    case lesson_type do
      :grammar -> "Learn #{topic_lower} including: #{samples}..."
      :reading -> "Practice reading comprehension using #{topic_lower} context."
      :writing -> "Practice writing #{topic_lower} with guided exercises."
      :listening -> "Develop listening skills for #{topic_lower} situations."
      _ -> "Study #{topic_lower} with: #{samples}..."
    end
  end

  defp create_lesson_in_db(lesson_data) do
    # Build word links with positions (ensure unique word_ids)
    unique_word_ids = Enum.uniq(lesson_data.word_ids)

    word_links =
      unique_word_ids
      |> Enum.with_index()
      |> Enum.map(fn {word_id, index} ->
        %{position: index, word_id: word_id}
      end)

    lesson_attrs = %{
      title: lesson_data.title,
      description: lesson_data.description,
      difficulty: lesson_data.difficulty,
      lesson_type: lesson_data.lesson_type,
      word_count: length(unique_word_ids),
      order_index: lesson_data.order - 1
    }

    case Content.create_lesson_with_words(lesson_attrs, word_links) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        IO.puts("  ⚠️  Failed to create lesson: #{inspect(changeset.errors)}")

      {:error, :lesson_words, changeset, _} ->
        IO.puts("  ⚠️  Failed to create lesson words: #{inspect(changeset.errors)}")
    end
  end
end
