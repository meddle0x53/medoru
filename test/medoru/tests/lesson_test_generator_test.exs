defmodule Medoru.Tests.LessonTestGeneratorTest do
  use Medoru.DataCase

  alias Medoru.Tests.LessonTestGenerator
  alias Medoru.Tests
  alias Medoru.Content

  describe "generate_lesson_test/2" do
    setup do
      # Create a lesson with words
      {:ok, lesson} =
        Content.create_lesson(%{
          title: "Test Lesson",
          description: "A test lesson",
          difficulty: 5,
          order_index: 1,
          lesson_type: :reading
        })

      # Create some words with valid Japanese
      words =
        for {text, reading, meaning} <- [
              {"日本", "にほん", "Japan"},
              {"学校", "がっこう", "School"},
              {"先生", "せんせい", "Teacher"}
            ] do
          {:ok, word} =
            Content.create_word(%{
              text: text,
              reading: reading,
              meaning: meaning,
              difficulty: 5
            })

          word
        end

      # Add words to lesson
      for {word, index} <- Enum.with_index(words) do
        Content.create_lesson_word(%{
          lesson_id: lesson.id,
          word_id: word.id,
          position: index
        })
      end

      %{lesson: lesson, words: words}
    end

    test "generates a test for a lesson", %{lesson: lesson} do
      assert {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id)
      assert test.test_type == :lesson
      assert test.status == :ready
      assert test.lesson_id == lesson.id

      # Should have 3 steps per word (default)
      steps = Tests.list_test_steps(test.id)
      assert length(steps) == 9
    end

    test "generates test with custom steps per word", %{lesson: lesson} do
      assert {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id, steps_per_word: 2)
      steps = Tests.list_test_steps(test.id)
      assert length(steps) == 6
    end

    test "updates lesson with test reference", %{lesson: lesson} do
      {:ok, test} = LessonTestGenerator.generate_lesson_test(lesson.id)

      # Reload lesson
      updated_lesson = Content.get_lesson!(lesson.id)
      assert updated_lesson.test_id == test.id
    end

    test "archives existing test when generating new one", %{lesson: lesson} do
      {:ok, test1} = LessonTestGenerator.generate_lesson_test(lesson.id)
      {:ok, test2} = LessonTestGenerator.generate_lesson_test(lesson.id)

      # First test should be archived
      archived = Tests.get_test!(test1.id)
      assert archived.status == :archived

      # Lesson should reference new test
      updated_lesson = Content.get_lesson!(lesson.id)
      assert updated_lesson.test_id == test2.id
    end

    test "returns error for lesson without words" do
      # Create empty lesson
      {:ok, empty_lesson} =
        Content.create_lesson(%{
          title: "Empty Lesson",
          description: "No words",
          difficulty: 5,
          order_index: 999,
          lesson_type: :reading
        })

      assert {:error, :no_words_in_lesson} =
               LessonTestGenerator.generate_lesson_test(empty_lesson.id)
    end
  end

  describe "get_or_create_lesson_test/2" do
    setup do
      {:ok, lesson} =
        Content.create_lesson(%{
          title: "Test Lesson",
          description: "A test lesson",
          difficulty: 5,
          order_index: 1,
          lesson_type: :reading
        })

      {:ok, word} =
        Content.create_word(%{
          text: "本",
          reading: "ほん",
          meaning: "Book",
          difficulty: 5
        })

      Content.create_lesson_word(%{
        lesson_id: lesson.id,
        word_id: word.id,
        position: 0
      })

      %{lesson: lesson}
    end

    test "creates test if none exists", %{lesson: lesson} do
      assert {:ok, test} = LessonTestGenerator.get_or_create_lesson_test(lesson.id)
      assert test.test_type == :lesson
    end

    test "returns existing published test", %{lesson: lesson} do
      {:ok, test1} = LessonTestGenerator.generate_lesson_test(lesson.id)

      assert {:ok, test2} = LessonTestGenerator.get_or_create_lesson_test(lesson.id)
      assert test1.id == test2.id
    end
  end
end
