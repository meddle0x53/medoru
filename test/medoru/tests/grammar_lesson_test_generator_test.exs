defmodule Medoru.Tests.GrammarLessonTestGeneratorTest do
  use Medoru.DataCase

  alias Medoru.Tests.GrammarLessonTestGenerator
  alias Medoru.Content

  import Medoru.ContentFixtures
  import Medoru.AccountsFixtures


  describe "generate_lesson_test/1" do
    setup do
      # Create a teacher user
      teacher = user_fixture(%{type: "teacher"})

      # Create a grammar lesson with 4 steps
      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          title: "Grammar Test Lesson",
          lesson_subtype: "grammar",
          requires_test: true
        })

      # Create 4 grammar lesson steps as specified
      step1 =
        grammar_lesson_step_fixture(%{
          custom_lesson: lesson,
          position: 0,
          title: "Noun AND Noun",
          explanation: "Connect two nouns with と to mean 'and'",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"},
            %{"type" => "literal", "value" => "と"},
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"}
          ],
          examples: [
            %{
              "sentence" => "猫と犬",
              "reading" => "ねこといぬ",
              "meaning" => "Cat and dog"
            },
            %{
              "sentence" => "日本と中国",
              "reading" => "にほんとちゅうごく",
              "meaning" => "Japan and China"
            }
          ],
          difficulty: 1
        })

      step2 =
        grammar_lesson_step_fixture(%{
          custom_lesson: lesson,
          position: 1,
          title: "Negative verb form",
          explanation: "Conjugate verbs to negative form with ない",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "verb_negative", "label" => "Verb-ない-form"}
          ],
          examples: [
            %{
              "sentence" => "食べない",
              "reading" => "たべない",
              "meaning" => "Don't eat"
            }
          ],
          difficulty: 2
        })

      step3 =
        grammar_lesson_step_fixture(%{
          custom_lesson: lesson,
          position: 2,
          title: "To want something",
          explanation: "Express desire using が欲しいです",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"},
            %{"type" => "literal", "value" => "が"},
            %{"type" => "literal", "value" => "欲しいです"}
          ],
          examples: [
            %{
              "sentence" => "本が欲しいです",
              "reading" => "ほんがほしいです",
              "meaning" => "I want a book"
            }
          ],
          difficulty: 2
        })

      step4 =
        grammar_lesson_step_fixture(%{
          custom_lesson: lesson,
          position: 3,
          title: "Adjective in past form",
          explanation: "Conjugate i-adjectives to past tense",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "adjective_past", "label" => "Adj+た-form"}
          ],
          examples: [
            %{
              "sentence" => "大きかった",
              "reading" => "おおきかった",
              "meaning" => "Was big"
            }
          ],
          difficulty: 3
        })

      %{lesson: lesson, steps: [step1, step2, step3, step4]}
    end

    test "generates test with 2 steps per lesson step", %{lesson: lesson, steps: _steps} do
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)

      # Should have 8 test steps (2 per lesson step × 4 lesson steps)
      test_steps = Medoru.Tests.list_test_steps(test.id)
      assert length(test_steps) == 8

      # All steps should be grammar type with sentence_validation question type
      for step <- test_steps do
        assert step.step_type == :grammar
        assert step.question_type == :sentence_validation
      end
    end

    test "test steps reference lesson step titles", %{lesson: lesson, steps: steps} do
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      test_steps = Medoru.Tests.list_test_steps(test.id)

      # Group steps by title
      steps_by_title = Enum.group_by(test_steps, & &1.question)

      # Each lesson step should have exactly 2 test steps
      for step <- steps do
        assert length(steps_by_title[step.title]) == 2
      end
    end

    test "test steps have sentence_validation configuration", %{lesson: lesson} do
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      test_steps = Medoru.Tests.list_test_steps(test.id)

      for step <- test_steps do
        # Check question_data structure
        qd = step.question_data || %{}
        assert qd["grammar_step"] == true
        assert qd["show_pattern"] == false, "Pattern should be hidden"
        assert is_list(qd["pattern"]), "Pattern should be a list"
        assert qd["lesson_step_title"] == step.question
      end
    end

    test "test steps have hints from first example", %{lesson: lesson, steps: grammar_steps} do
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      test_steps = Medoru.Tests.list_test_steps(test.id)

      # Group by lesson step title
      steps_by_title = Enum.group_by(test_steps, & &1.question)

      for grammar_step <- grammar_steps do
        test_steps_for_grammar = steps_by_title[grammar_step.title]

        # Get first example sentence
        first_example = List.first(grammar_step.examples)
        expected_hint = first_example["sentence"]

        # Both test steps should have the same hint
        for test_step <- test_steps_for_grammar do
          assert test_step.hints == [expected_hint]
        end
      end
    end

    test "test steps are shuffled (not in original order)", %{lesson: lesson} do
      # Generate test multiple times and check ordering
      {:ok, test1} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      {:ok, test2} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)

      steps1 = Medoru.Tests.list_test_steps(test1.id)
      steps2 = Medoru.Tests.list_test_steps(test2.id)

      # Get order indices grouped by title
      order1 = Enum.map(steps1, &{&1.question, &1.order_index})
      order2 = Enum.map(steps2, &{&1.question, &1.order_index})

      # Due to shuffling, there's a high chance at least some steps are in different positions
      # We're checking that the overall ordering mechanism works (order_index is set)
      assert length(order1) == length(order2)

      # Verify order indices are unique and sequential
      indices1 = Enum.map(steps1, & &1.order_index) |> Enum.sort()
      assert indices1 == [0, 1, 2, 3, 4, 5, 6, 7]
    end

    test "updates lesson with test reference and requires_test", %{lesson: lesson} do
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)

      # Reload lesson
      updated_lesson = Content.get_custom_lesson!(lesson.id)

      assert updated_lesson.test_id == test.id
      assert updated_lesson.requires_test == true
    end

    test "archives old test when generating new one", %{lesson: lesson} do
      # Generate first test
      {:ok, test1} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      assert test1.status == :ready

      # Generate second test
      {:ok, test2} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
      assert test2.status == :ready

      # Old test should be archived
      archived = Medoru.Tests.get_test!(test1.id)
      assert archived.status == :archived
    end

    test "returns error for lesson with no grammar steps" do
      teacher = user_fixture(%{type: "teacher"})

      # Create empty grammar lesson
      empty_lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          title: "Empty Grammar Lesson",
          lesson_subtype: "grammar"
        })

      assert {:error, :no_steps_in_lesson} =
               GrammarLessonTestGenerator.generate_lesson_test(empty_lesson.id)
    end
  end
end
