defmodule Medoru.Tests.CustomLessonLocaleTest do
  use Medoru.DataCase

  alias Medoru.Tests.{CustomLessonTestGenerator, TestStepAnswer}
  alias Medoru.Content

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "custom lesson test with different locales" do
    setup do
      # Create teacher and student
      teacher = user_fixture_with_registration(%{type: "teacher"})
      _student = user_fixture_with_registration(%{type: "student"})

      # Create a custom lesson with words
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Basic Words",
          creator_id: teacher.id,
          status: "published",
          requires_test: true
        })

      # Create words with translations
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん", difficulty: 5})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう", difficulty: 5})
      word3 = word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい", difficulty: 5})

      # Add words to lesson
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word3.id, %{position: 2})

      %{teacher: teacher, lesson: lesson, words: [word1, word2, word3]}
    end

    test "multichoice question stores option_word_ids for validation", %{
      lesson: lesson,
      words: _words
    } do
      # Generate test with more steps to ensure we get multichoice steps
      {:ok, test} = CustomLessonTestGenerator.generate_lesson_test(lesson.id, steps_per_word: 4)

      # Get test steps
      steps = Medoru.Tests.list_test_steps(test.id)

      # Find any multichoice step (which should have option_word_ids)
      multichoice_step =
        Enum.find(steps, fn step ->
          step.question_type == :multichoice
        end)

      assert multichoice_step, "Should have a multichoice step"

      # Verify option_word_ids is stored
      question_data = multichoice_step.question_data || %{}
      option_word_ids = question_data["option_word_ids"] || question_data[:option_word_ids]

      assert option_word_ids,
             "Should have option_word_ids in question_data: #{inspect(question_data)}"

      assert length(option_word_ids) >= 2, "Should have at least 2 options"
    end

    test "answer validation uses word_id when option_word_ids present" do
      # The real scenario: 
      # - Teacher creates test with EN locale
      # - step.options stores English meanings: ["Japan", "school", "teacher"]
      # - step.correct_answer stores "Japan" (English)
      # - Student clicks button that sends phx-value-answer="Japan" (English)
      # - UI displays localized meanings (e.g., Bulgarian) but sends English value
      #
      # The bug was: if options were somehow localized, text comparison would fail
      # The fix: Use word_id comparison which works regardless of text locale

      # Stored in English (this is what the database stores)
      correct_answer_text = "Japan"
      # Student's answer is also English (from phx-value-answer)
      student_answer_text = "Japan"

      # The fix: When option_word_ids are present, validate by word_id
      # This ensures correctness even if there were any localization issues
      option_word_ids = ["word-123", "word-456", "word-789"]
      # English meanings (what's stored in the database)
      options = ["Japan", "school", "teacher"]

      question_data = %{
        "option_word_ids" => option_word_ids,
        "options" => options
      }

      # Use the actual validate_answer function
      is_correct =
        TestStepAnswer.validate_answer(student_answer_text, correct_answer_text, question_data)

      assert is_correct,
             "FIX: validate_answer should work with word_id comparison"

      # Test incorrect answer
      wrong_answer = "school"

      is_incorrect =
        TestStepAnswer.validate_answer(wrong_answer, correct_answer_text, question_data)

      refute is_incorrect, "Wrong answer should be marked incorrect"
    end

    test "full integration: student with different locale answers correctly", %{
      lesson: lesson,
      words: words
    } do
      import Medoru.Tests
      import Medoru.AccountsFixtures

      # Generate test (teacher creates it, English locale)
      {:ok, test} = CustomLessonTestGenerator.generate_lesson_test(lesson.id)

      # Get test steps
      steps = list_test_steps(test.id)

      # Find a word_to_meaning step
      meaning_step =
        Enum.find(steps, fn step ->
          step.question_type == :multichoice &&
            step.correct_answer in Enum.map(words, & &1.meaning)
        end)

      assert meaning_step, "Should have a word_to_meaning step"

      # Create a student and start a test session
      student = user_fixture_with_registration(%{type: "student"})
      {:ok, session} = start_test_session(student.id, test.id)

      # Get the correct word
      correct_word = Enum.find(words, &(&1.meaning == meaning_step.correct_answer))
      assert correct_word, "Should find the correct word"

      # Simulate student answering with English text (what phx-value-answer sends)
      # The student sees Bulgarian "Япония" but clicks button that sends "Japan"
      answer = meaning_step.correct_answer

      # Record the answer with Bulgarian locale
      assert {:ok, %TestStepAnswer{} = step_answer} =
               record_step_answer(
                 session.id,
                 meaning_step.id,
                 %{
                   "answer" => answer,
                   "time_spent_seconds" => 10,
                   "step_index" => 0
                 },
                 locale: "bg"
               )

      # Should be marked correct
      assert step_answer.is_correct == true,
             "Should be marked correct when answer matches correct_answer text"

      # Now test an incorrect answer
      wrong_answer =
        Enum.find(meaning_step.options, &(&1 != meaning_step.correct_answer))

      {:ok, session2} = start_test_session(student.id, test.id)

      assert {:ok, %TestStepAnswer{} = wrong_step_answer} =
               record_step_answer(
                 session2.id,
                 meaning_step.id,
                 %{
                   "answer" => wrong_answer,
                   "time_spent_seconds" => 10,
                   "step_index" => 0
                 },
                 locale: "bg"
               )

      assert wrong_step_answer.is_correct == false,
             "Should be marked incorrect when answer is wrong"
    end
  end

  describe "custom lesson test with images" do
    setup do
      # Create teacher
      teacher = user_fixture_with_registration(%{type: "teacher"})

      # Create a custom lesson with words that have images
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Food Vocabulary",
          creator_id: teacher.id,
          status: "published",
          requires_test: true
        })

      # Create words with images
      word1 =
        word_fixture(%{
          text: "りんご",
          meaning: "apple",
          reading: "りんご",
          difficulty: 5,
          image_path: "/uploads/word_images/apple.png"
        })

      word2 =
        word_fixture(%{
          text: "みかん",
          meaning: "orange",
          reading: "みかん",
          difficulty: 5,
          image_path: "/uploads/word_images/orange.png"
        })

      word3 =
        word_fixture(%{
          text: "バナナ",
          meaning: "banana",
          reading: "バナナ",
          difficulty: 5,
          image_path: "/uploads/word_images/banana.png"
        })

      word4 =
        word_fixture(%{
          text: "ぶどう",
          meaning: "grape",
          reading: "ぶどう",
          difficulty: 5,
          image_path: "/uploads/word_images/grape.png"
        })

      # Add words to lesson
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word3.id, %{position: 2})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word4.id, %{position: 3})

      %{teacher: teacher, lesson: lesson, words: [word1, word2, word3, word4]}
    end

    test "generates image_to_meaning questions when words have images", %{
      lesson: lesson,
      words: _words
    } do
      # Generate test with enough steps to likely include image questions
      {:ok, test} = CustomLessonTestGenerator.generate_lesson_test(lesson.id, steps_per_word: 5)

      # Get test steps
      steps = Medoru.Tests.list_test_steps(test.id)

      # Find image questions
      image_steps =
        Enum.filter(steps, fn step ->
          get_in(step.question_data, ["type"]) == "image_to_meaning" or
            get_in(step.question_data, [:type]) == :image_to_meaning
        end)

      # Should have at least one image question when words have images
      assert length(image_steps) >= 1, "Should generate image questions when words have images"

      # Verify image questions have image_options
      for step <- image_steps do
        image_options =
          get_in(step.question_data, ["image_options"]) ||
            get_in(step.question_data, [:image_options])

        assert image_options != nil, "Image question should have image_options"
        assert length(image_options) >= 2, "Should have at least 2 image options"
      end
    end

    test "handles words without images gracefully", %{
      teacher: teacher
    } do
      # Create a lesson with words that don't have images
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Small Vocabulary No Images",
          creator_id: teacher.id,
          status: "published",
          requires_test: true
        })

      word1 =
        word_fixture(%{
          text: "山",
          meaning: "mountain",
          reading: "やま",
          difficulty: 5,
          image_path: nil
        })

      word2 =
        word_fixture(%{
          text: "川",
          meaning: "river",
          reading: "かわ",
          difficulty: 5,
          image_path: nil
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})

      # Generate test - should work even without images
      {:ok, test} = CustomLessonTestGenerator.generate_lesson_test(lesson.id, steps_per_word: 3)

      steps = Medoru.Tests.list_test_steps(test.id)

      # All multichoice steps should be valid with options
      multichoice_steps = Enum.filter(steps, &(&1.question_type == :multichoice))

      for step <- multichoice_steps do
        assert length(step.options) >= 2, "Each question should have at least 2 options"
        assert step.correct_answer in step.options, "Correct answer should be in options"
      end
    end
  end
end
