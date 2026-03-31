defmodule MedoruWeb.ClassroomLive.GrammarLessonTestTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures

  alias Medoru.Content
  alias Medoru.Classrooms
  alias Medoru.Tests.GrammarLessonTestGenerator

  describe "grammar lesson with generated test" do
    setup do
      # Create teacher
      teacher = user_fixture(%{type: "teacher"})

      # Create student
      student = user_fixture(%{type: "student", email: "student_grammar_test@example.com"})

      # Create classroom
      {:ok, classroom} =
        Classrooms.create_classroom(%{name: "Test Grammar Classroom", teacher_id: teacher.id})

      # Student applies to join classroom
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)

      # Teacher approves student
      {:ok, _} = Classrooms.approve_membership(membership)

      %{
        teacher: teacher,
        student: student,
        classroom: classroom
      }
    end

    test "teacher creates grammar lesson, system generates test with correct structure", %{
      classroom: classroom,
      teacher: teacher
    } do
      # ============================================
      # STEP 1: Teacher creates grammar lesson with 4 steps
      # ============================================
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Grammar Basics",
          description: "Learn basic grammar patterns",
          lesson_type: "reading",
          lesson_subtype: "grammar",
          difficulty: 1,
          status: "draft",
          creator_id: teacher.id,
          requires_test: true
        })

      # Create 4 grammar steps as specified in requirements
      steps_data = [
        %{
          title: "Noun AND Noun",
          explanation: "Connect two nouns with と to mean 'and'",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"},
            %{"type" => "literal", "value" => "と"},
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"}
          ],
          examples: [
            %{"sentence" => "猫と犬", "reading" => "ねこといぬ", "meaning" => "Cat and dog"}
          ]
        },
        %{
          title: "Negative verb form",
          explanation: "Conjugate verbs to negative form with ない",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "verb_negative", "label" => "Verb-ない-form"}
          ],
          examples: [
            %{"sentence" => "食べない", "reading" => "たべない", "meaning" => "Don't eat"}
          ]
        },
        %{
          title: "To want something",
          explanation: "Express desire using が欲しいです",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "noun", "label" => "Noun"},
            %{"type" => "literal", "value" => "が"},
            %{"type" => "literal", "value" => "欲しいです"}
          ],
          examples: [
            %{"sentence" => "本が欲しいです", "reading" => "ほんがほしいです", "meaning" => "I want a book"}
          ]
        },
        %{
          title: "Adjective in past form",
          explanation: "Conjugate i-adjectives to past tense",
          pattern_elements: [
            %{"type" => "slot", "slot_type" => "adjective_past", "label" => "Adj+た-form"}
          ],
          examples: [
            %{"sentence" => "大きかった", "reading" => "おおきかった", "meaning" => "Was big"}
          ]
        }
      ]

      for {step_attrs, index} <- Enum.with_index(steps_data) do
        {:ok, _step} =
          Content.create_grammar_lesson_step(%{
            custom_lesson_id: lesson.id,
            position: index,
            title: step_attrs.title,
            explanation: step_attrs.explanation,
            pattern_elements: step_attrs.pattern_elements,
            examples: step_attrs.examples,
            difficulty: 1
          })
      end

      # ============================================
      # STEP 2: Teacher publishes lesson to classroom
      # ============================================
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      # Generate test for the lesson
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)

      # ============================================
      # STEP 3: Verify test generation - 8 test steps total
      # ============================================
      test_steps = Medoru.Tests.list_test_steps(test.id)

      # Should have 8 test steps (2 per lesson step × 4 lesson steps)
      assert length(test_steps) == 8

      # All steps should be grammar type with sentence_validation question type
      for step <- test_steps do
        assert step.step_type == :grammar
        assert step.question_type == :sentence_validation
        # Grammar pattern should be hidden
        assert step.question_data["show_pattern"] == false
        assert step.question_data["grammar_step"] == true
        # Pattern should be present for validation
        assert is_list(step.question_data["pattern"])
      end

      # ============================================
      # STEP 4: Verify test step titles
      # ============================================
      # Steps should have titles from lesson steps
      titles = Enum.map(test_steps, & &1.question) |> Enum.uniq() |> Enum.sort()

      expected_titles = [
        "Adjective in past form",
        "Negative verb form",
        "Noun AND Noun",
        "To want something"
      ]

      assert titles == expected_titles

      # Each lesson step should have exactly 2 test steps
      steps_by_title = Enum.group_by(test_steps, & &1.question)

      for title <- expected_titles do
        assert length(steps_by_title[title]) == 2
      end

      # ============================================
      # STEP 5: Verify hints from first example
      # ============================================
      for {step_data, _index} <- Enum.with_index(steps_data) do
        test_steps_for_title = steps_by_title[step_data.title]
        assert length(test_steps_for_title) == 2

        # Hint should be the first example's kanji sentence
        first_example = List.first(step_data.examples)
        expected_hint = first_example["sentence"]

        for test_step <- test_steps_for_title do
          assert test_step.hints == [expected_hint]
        end
      end

      # ============================================
      # STEP 6: Verify lesson updated with test reference
      # ============================================
      lesson = Content.get_custom_lesson!(lesson.id)
      assert lesson.requires_test == true
      assert lesson.test_id == test.id

      # ============================================
      # STEP 7: Verify test is shuffled (order indices)
      # ============================================
      order_indices = Enum.map(test_steps, & &1.order_index) |> Enum.sort()
      assert order_indices == [0, 1, 2, 3, 4, 5, 6, 7]
    end

    test "second student - different lesson setup with 2 steps", %{
      classroom: classroom,
      teacher: teacher
    } do
      # Create a second student
      student2 = user_fixture(%{type: "student", email: "student2_grammar@example.com"})

      # Student applies to join and gets approved
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student2.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      # Create and publish grammar lesson with 2 steps
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Grammar Basics Student 2",
          description: "Learn basic grammar patterns",
          lesson_type: "reading",
          lesson_subtype: "grammar",
          difficulty: 1,
          status: "draft",
          creator_id: teacher.id,
          requires_test: true
        })

      # Create 2 steps for quicker test
      for {title, index} <- Enum.with_index(["Noun AND Noun", "Negative verb form"]) do
        {:ok, _} =
          Content.create_grammar_lesson_step(%{
            custom_lesson_id: lesson.id,
            position: index,
            title: title,
            explanation: "Test explanation",
            pattern_elements: [%{"type" => "literal", "value" => "と"}],
            examples: [%{"sentence" => "テスト", "reading" => "てすと", "meaning" => "Test"}],
            difficulty: 1
          })
      end

      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)
      {:ok, test} = GrammarLessonTestGenerator.generate_lesson_test(lesson.id)

      # Verify 4 test steps generated (2 per lesson step)
      test_steps = Medoru.Tests.list_test_steps(test.id)
      assert length(test_steps) == 4

      # All steps are sentence_validation
      for step <- test_steps do
        assert step.step_type == :grammar
        assert step.question_type == :sentence_validation
      end

      # Verify lesson is properly linked
      lesson = Content.get_custom_lesson!(lesson.id)
      assert lesson.test_id == test.id
      assert lesson.requires_test == true
    end
  end
end
