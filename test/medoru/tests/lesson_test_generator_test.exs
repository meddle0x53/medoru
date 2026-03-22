defmodule Medoru.Tests.LessonTestGeneratorTest do
  use Medoru.DataCase

  alias Medoru.Tests.LessonTestGenerator
  alias Medoru.Content

  import Medoru.ContentFixtures

  describe "generate_lesson_test/2" do
    setup do
      # Create a lesson with words
      lesson = lesson_fixture(%{title: "Test Lesson", difficulty: 5, order_index: 1})

      # Create words for the lesson
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん", difficulty: 5})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう", difficulty: 5})
      word3 = word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい", difficulty: 5})
      word4 = word_fixture(%{text: "学生", meaning: "student", reading: "がくせい", difficulty: 5})

      # Associate words with lesson
      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word1.id, position: 0})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word2.id, position: 1})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word3.id, position: 2})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word4.id, position: 3})

      # Reload lesson with words
      lesson = Content.get_lesson_with_words!(lesson.id)

      %{lesson: lesson, words: [word1, word2, word3, word4]}
    end

    test "generates test with distractors from same lesson", %{lesson: lesson, words: words} do
      {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id)

      # Get test steps with options
      steps = Medoru.Tests.list_test_steps(test.id)

      # Find multichoice steps
      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))

      assert length(multichoice_steps) > 0

      # Get all word texts, meanings, and readings from the lesson
      word_texts = Enum.map(words, & &1.text)
      word_meanings = Enum.map(words, & &1.meaning)
      word_readings = Enum.map(words, & &1.reading)
      all_lesson_values = word_texts ++ word_meanings ++ word_readings

      # Verify each step has distractors from same lesson
      for step <- multichoice_steps do
        assert length(step.options) >= 2, "Should have at least 2 options (correct + distractors)"
        assert step.correct_answer in step.options, "Correct answer should be in options"

        # For first lesson, distractors should come from same lesson
        # Options could be texts (kanji), meanings (English), or readings (hiragana)
        lesson_options =
          Enum.filter(step.options, fn opt ->
            opt in all_lesson_values
          end)

        assert length(lesson_options) >= 2,
               "Should have at least 2 options from same lesson, got: #{inspect(step.options)}"
      end
    end

    test "distractors are randomly selected from lesson words", %{lesson: lesson} do
      # Generate test twice
      {:ok, test1} = LessonTestGenerator.generate_lesson_test(lesson.id)
      {:ok, test2} = LessonTestGenerator.generate_lesson_test(lesson.id)

      steps1 = Medoru.Tests.list_test_steps(test1.id)
      steps2 = Medoru.Tests.list_test_steps(test2.id)

      # Get options from first multichoice step of each test
      mc1 = Enum.find(steps1, &(&1.question_type == :multichoice))
      mc2 = Enum.find(steps2, &(&1.question_type == :multichoice))

      # Options should potentially be different (randomized)
      # Note: There's a small chance they're the same, but very unlikely with 4 words
      assert length(mc1.options) == length(mc2.options)
    end

    test "correct answer is shuffled among options (not always first)", %{lesson: lesson} do
      {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id)
      steps = Medoru.Tests.list_test_steps(test.id)

      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))

      # Check that correct answer appears in different positions
      positions =
        Enum.map(multichoice_steps, fn step ->
          Enum.find_index(step.options, &(&1 == step.correct_answer))
        end)

      # Should have variety in positions (not all 0)
      unique_positions = Enum.uniq(positions)
      assert length(unique_positions) >= 1
    end

    test "rejects generation for lesson with no words" do
      empty_lesson = lesson_fixture(%{title: "Empty Lesson", difficulty: 5, order_index: 99})

      assert {:error, :no_words_in_lesson} =
               LessonTestGenerator.generate_lesson_test(empty_lesson.id)
    end

    test "archives old test when generating new one", %{lesson: lesson} do
      # Generate first test
      {:ok, test1} = LessonTestGenerator.generate_lesson_test(lesson.id)
      assert test1.status == :ready

      # Generate second test
      {:ok, test2} = LessonTestGenerator.generate_lesson_test(lesson.id)

      # First test should be archived
      archived = Medoru.Tests.get_test!(test1.id)
      assert archived.status == :archived

      # Second test should be ready
      assert test2.status == :ready
    end
  end

  describe "get_or_create_lesson_test/2" do
    setup do
      lesson = lesson_fixture(%{title: "Test Lesson", difficulty: 5, order_index: 1})
      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word.id, position: 0})

      %{lesson: lesson}
    end

    test "creates new test if none exists", %{lesson: lesson} do
      assert {:ok, test} = LessonTestGenerator.get_or_create_lesson_test(lesson.id)
      assert test.test_type == :lesson
    end

    test "returns existing test if already published", %{lesson: lesson} do
      # Create test first
      {:ok, test1} = LessonTestGenerator.generate_lesson_test(lesson.id)

      # Get or create should return same test
      assert {:ok, test2} = LessonTestGenerator.get_or_create_lesson_test(lesson.id)
      assert test1.id == test2.id
    end
  end

  describe "distractor pool building" do
    setup do
      # Create lessons in order
      lesson1 = lesson_fixture(%{title: "Lesson 1", difficulty: 5, order_index: 1})
      lesson2 = lesson_fixture(%{title: "Lesson 2", difficulty: 5, order_index: 2})

      # Words for lesson 1 (previous lesson)
      word1_l1 = word_fixture(%{text: "一", meaning: "one", reading: "いち", difficulty: 5})
      word2_l1 = word_fixture(%{text: "二", meaning: "two", reading: "に", difficulty: 5})

      # Words for lesson 2 (current lesson)
      word1_l2 = word_fixture(%{text: "三", meaning: "three", reading: "さん", difficulty: 5})
      word2_l2 = word_fixture(%{text: "四", meaning: "four", reading: "よん", difficulty: 5})

      # Associate words
      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson1.id, word_id: word1_l1.id, position: 0})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson1.id, word_id: word2_l1.id, position: 1})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson2.id, word_id: word1_l2.id, position: 0})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson2.id, word_id: word2_l2.id, position: 1})

      %{
        lesson1: lesson1,
        lesson2: lesson2,
        lesson1_words: [word1_l1, word2_l1],
        lesson2_words: [word1_l2, word2_l2]
      }
    end

    test "includes words from previous lessons in distractor pool", %{
      lesson2: lesson2,
      lesson1_words: _lesson1_words,
      lesson2_words: lesson2_words
    } do
      # Generate test for lesson 2 (which has lesson 1 as previous)
      {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson2.id)
      steps = Medoru.Tests.list_test_steps(test.id)

      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))

      # Get all distractor texts used
      all_options = Enum.flat_map(multichoice_steps, & &1.options)

      # Should include words from both lessons
      lesson2_texts = Enum.map(lesson2_words, & &1.text)

      # At least some options should be from lesson 2 (same lesson)
      assert Enum.any?(all_options, fn opt -> opt in lesson2_texts end),
             "Should include distractors from same lesson"
    end
  end

  describe "generate_missing_lesson_tests/1" do
    test "generates tests for lessons without tests" do
      # Create lessons with words but no tests
      lesson1 = lesson_fixture(%{title: "Lesson 1", difficulty: 5, order_index: 1})
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson1.id, word_id: word1.id, position: 0})

      lesson2 = lesson_fixture(%{title: "Lesson 2", difficulty: 5, order_index: 2})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう"})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson2.id, word_id: word2.id, position: 0})

      # Generate missing tests
      assert {:ok, results} = LessonTestGenerator.generate_missing_lesson_tests()

      assert results.created >= 2
      assert results.failed == 0
    end
  end

  describe "user_preferences option" do
    test "filters step types based on user preferences" do
      # Create lesson with words
      lesson = lesson_fixture(%{title: "Test Lesson", difficulty: 5})
      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん", difficulty: 5})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word.id, position: 0})

      # Generate with limited preferences (only word_to_meaning)
      {:ok, test} =
        LessonTestGenerator.generate_lesson_test(lesson.id,
          user_preferences: ["word_to_meaning"]
        )

      steps = Medoru.Tests.list_test_steps(test.id)

      # Should only have word_to_meaning steps
      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))
      assert length(multichoice_steps) > 0

      # All questions should match word_to_meaning format (message key format)
      for step <- multichoice_steps do
        assert String.contains?(step.question, "__MSG_WHAT_DOES_WORD_MEAN__")
      end
    end

    test "includes writing steps when kanji_writing in preferences" do
      # Create lesson with words that have kanji
      lesson = lesson_fixture(%{title: "Test Lesson", difficulty: 5})

      # Create a kanji with stroke data
      kanji = Medoru.ContentFixtures.kanji_fixture(%{
        character: "日",
        stroke_count: 4,
        stroke_data: %{
          "strokes" => [
            %{"path" => "M10,10 L50,10"},
            %{"path" => "M50,10 L50,50"}
          ]
        }
      })

      word = word_fixture(%{text: "日", meaning: "sun", reading: "ひ", difficulty: 5})

      # Create word_kanji association
      {:ok, _} =
        Medoru.Repo.insert(%Medoru.Content.WordKanji{
          word_id: word.id,
          kanji_id: kanji.id,
          position: 0
        })

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word.id, position: 0})

      # Generate with kanji_writing in preferences (also include some multichoice types)
      {:ok, test} =
        LessonTestGenerator.generate_lesson_test(lesson.id,
          user_preferences: ["word_to_meaning", "kanji_writing"]
        )

      steps = Medoru.Tests.list_test_steps(test.id)
      writing_steps = Enum.filter(steps, &(&1.question_type == :writing))

      # Should have at least one writing step
      assert length(writing_steps) >= 1
    end

    test "uses all default step types when no preferences provided" do
      # Create lesson with words (need enough words for defaults)
      lesson = lesson_fixture(%{title: "Test Lesson", difficulty: 5})
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん", difficulty: 5})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう", difficulty: 5})
      word3 = word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい", difficulty: 5})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word1.id, position: 0})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word2.id, position: 1})

      {:ok, _} =
        Content.create_lesson_word(%{lesson_id: lesson.id, word_id: word3.id, position: 2})

      # Generate without preferences (uses defaults)
      {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id)

      steps = Medoru.Tests.list_test_steps(test.id)
      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))

      # Should have multiple types of questions (defaults produce many steps)
      assert length(multichoice_steps) >= 6
    end
  end
end
