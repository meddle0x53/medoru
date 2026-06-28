defmodule Medoru.Tests.ClassroomVocabularyTestGeneratorTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests
  alias Medoru.Tests.ClassroomVocabularyTestGenerator

  describe "generate_test/4" do
    setup do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      lesson = custom_lesson_fixture(%{creator_id: teacher.id, lesson_subtype: "vocabulary"})

      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "一", meaning: "one", reading: "いち"})
      word3 = word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"})
      word4 = word_fixture(%{text: "あまい", meaning: "sweet", reading: "あまい"})

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word3.id, %{position: 2})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word4.id, %{position: 3})

      # Publish lesson to classroom
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{
        classroom: classroom,
        teacher: teacher,
        lesson: lesson,
        words: [word1, word2, word3, word4]
      }
    end

    test "generates and publishes a test to the classroom", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 4,
                 title: "Generated Test"
               )

      assert test.title == "Generated Test"
      assert test.test_type == :teacher
      assert test.setup_state == "published"
      assert test.total_points == 4

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 4

      # Published to classroom
      classroom_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
      assert Enum.any?(classroom_tests, &(&1.test_id == test.id))
    end

    test "limits total questions", %{classroom: classroom, teacher: teacher, words: words} do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning],
                 max_times_per_word: 2,
                 total_questions: 5
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 5
    end

    test "returns error when no words are selected", %{
      classroom: classroom,
      teacher: teacher
    } do
      assert {:error, :no_words_selected} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 [],
                 teacher.id,
                 step_types: [:word_to_meaning]
               )
    end

    test "returns error when no questions are possible", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      assert {:error, :no_questions_possible} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:image_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 4
               )
    end

    test "filters invalid step types", %{classroom: classroom, teacher: teacher, words: words} do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning, :invalid_type],
                 max_times_per_word: 1,
                 total_questions: 4
               )

      assert test.metadata["step_types"] == ["word_to_meaning"]
    end

    test "clamps max_times_per_word to 3", %{classroom: classroom, teacher: teacher, words: words} do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning],
                 max_times_per_word: 10,
                 total_questions: 12
               )

      assert test.metadata["max_times_per_word"] == 3
      assert test.total_points == 12

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 12
    end
  end
end
