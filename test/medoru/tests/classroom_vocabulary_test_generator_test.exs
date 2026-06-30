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

    test "generates reading_text steps", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:reading_text],
                 max_times_per_word: 1,
                 total_questions: 4
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 4

      Enum.each(test.test_steps, fn step ->
        assert step.question_type == :reading_text
        assert step.step_type == :vocabulary
        assert step.points == 2
        assert step.question_data["word_text"]
        assert step.question_data["word_reading"]
        assert step.question_data["word_meaning"]
        assert is_boolean(step.question_data["is_kana_only"])

        decoded = Jason.decode!(step.correct_answer)
        assert decoded["meaning"]
        assert decoded["reading"]
      end)
    end

    test "generates image_to_meaning steps with image options", %{
      classroom: classroom,
      teacher: teacher,
      lesson: lesson
    } do
      image_words = [
        %{text: "写真", meaning: "photo", reading: "しゃしん"},
        %{text: "絵", meaning: "picture", reading: "え"},
        %{text: "地図", meaning: "map", reading: "ちず"},
        %{text: "本", meaning: "book", reading: "ほん"}
      ]

      words_with_images =
        Enum.with_index(image_words, 1)
        |> Enum.map(fn {attrs, i} ->
          word =
            word_fixture(
              attrs
              |> Map.put(:image_path, "/uploads/word_#{i}.jpg")
              |> Map.to_list()
            )

          {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: i + 10})
          word
        end)

      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words_with_images,
                 teacher.id,
                 step_types: [:image_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 4
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 4

      Enum.each(test.test_steps, fn step ->
        assert step.question_type == :image_to_meaning
        assert step.correct_answer
        assert length(step.options) == 4
        assert length(step.question_data["image_options"]) == 4
        assert length(step.question_data["option_word_ids"]) == 4
      end)
    end

    test "generates kanji_writing steps worth 5 points", %{
      classroom: classroom,
      teacher: teacher,
      lesson: lesson
    } do
      word = word_with_kanji_fixture()
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 100})

      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 [word],
                 teacher.id,
                 step_types: [:kanji_writing],
                 max_times_per_word: 1,
                 total_questions: 1
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      step = hd(test.test_steps)
      assert step.question_type == :writing
      assert step.step_type == :writing
      assert step.points == 5
      assert step.kanji_id
    end

    test "skips step types that a word cannot satisfy", %{
      classroom: classroom,
      teacher: teacher,
      lesson: lesson
    } do
      word_without_image =
        word_fixture(%{text: "たべる", meaning: "to eat", reading: "たべる"})

      image_word =
        word_fixture(%{
          text: "写真",
          meaning: "photo",
          reading: "しゃしん",
          image_path: "/uploads/photo.jpg"
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word_without_image.id, %{position: 200})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, image_word.id, %{position: 201})

      # Need 4 image words so image_to_meaning stays enabled, but only one will be selected.
      extra_image_words =
        [
          %{text: "絵", meaning: "picture", reading: "え"},
          %{text: "地図", meaning: "map", reading: "ちず"},
          %{text: "本", meaning: "book", reading: "ほん"}
        ]
        |> Enum.with_index()
        |> Enum.map(fn {attrs, i} ->
          word_fixture(
            attrs
            |> Map.put(:image_path, "/uploads/#{i + 1}.jpg")
            |> Map.to_list()
          )
        end)

      Enum.with_index(extra_image_words, 202)
      |> Enum.each(fn {word, i} ->
        {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: i})
      end)

      selected_words = [word_without_image]

      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 selected_words,
                 teacher.id,
                 step_types: [:word_to_meaning, :image_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 1
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      refute hd(test.test_steps).question_type == :image_to_meaning
    end

    test "distributes selected step types across words", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning, :word_to_reading],
                 max_times_per_word: 1,
                 total_questions: 4
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      question_types = Enum.map(test.test_steps, & &1.question_data["question_label"])

      assert "meaning" in question_types
      assert "reading" in question_types
    end

    test "max_times_per_word limits total appearances across all step types", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning, :word_to_reading],
                 max_times_per_word: 1,
                 total_questions: 8
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 4

      word_ids = Enum.map(test.test_steps, & &1.word_id)
      assert length(word_ids) == length(Enum.uniq(word_ids))
    end

    test "passes due_date and max_attempts to classroom publication", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      due_date = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 words,
                 teacher.id,
                 step_types: [:word_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 4,
                 due_date: due_date,
                 max_attempts: 3
               )

      classroom_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
      classroom_test = Enum.find(classroom_tests, &(&1.test_id == test.id))

      assert classroom_test
      assert classroom_test.due_date == due_date
      assert classroom_test.max_attempts == 3
    end

    test "uses classroom-wide distractors when distractor_pool is :classroom", %{
      classroom: classroom,
      teacher: teacher,
      words: words
    } do
      [selected_word | _] = words

      assert {:ok, test} =
               ClassroomVocabularyTestGenerator.generate_test(
                 classroom,
                 [selected_word],
                 teacher.id,
                 step_types: [:word_to_meaning],
                 max_times_per_word: 1,
                 total_questions: 1,
                 distractor_pool: :classroom,
                 all_classroom_words: words
               )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      step = hd(test.test_steps)

      assert length(step.options) == 4
      unselected_meanings = Enum.map(words -- [selected_word], & &1.meaning)
      assert Enum.any?(step.options, &(&1 in unselected_meanings))
    end
  end
end
