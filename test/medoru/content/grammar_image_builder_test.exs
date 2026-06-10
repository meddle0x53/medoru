defmodule Medoru.Content.GrammarImageBuilderTest do
  use Medoru.DataCase

  alias Medoru.Content.GrammarImageBuilder
  alias Medoru.Content

  import Medoru.AccountsFixtures

  describe "build_lesson_from_extracted_grammar/3" do
    setup do
      user = user_fixture(%{type: "admin"})
      {:ok, user: user}
    end

    test "returns error for empty sections", %{user: user} do
      data = %{"title" => "Test", "sections" => []}
      assert {:error, "No grammar sections found"} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(data, %{}, user.id)
    end

    test "creates a grammar lesson with grammar and text steps", %{user: user} do
      data = %{
        "title" => "IV. Grammar Notes",
        "sections" => [
          %{
            "number" => 1,
            "title" => "V て-form",
            "description" => "The te-form of verbs.",
            "examples" => [
              %{"sentence" => "食べて", "reading" => "たべて", "meaning" => "eat (te-form)"}
            ],
            "step_type" => "grammar"
          },
          %{
            "number" => 2,
            "title" => "Verb Groups",
            "description" => "Verbs are classified into three groups.",
            "examples" => [],
            "step_type" => "text"
          }
        ]
      }

      assert {:ok, lesson} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(
                 data,
                 %{title: "My Grammar Lesson"},
                 user.id
               )

      assert lesson.title == "My Grammar Lesson"
      assert lesson.lesson_subtype == "grammar"
      assert lesson.status == "draft"

      steps = Content.list_grammar_lesson_steps(lesson.id)
      assert length(steps) == 2

      [grammar_step, text_step] = steps
      assert grammar_step.step_type == "grammar"
      assert grammar_step.title == "V て-form"
      assert grammar_step.explanation == "The te-form of verbs."
      assert length(grammar_step.examples) == 1
      example = hd(grammar_step.examples)
      assert example["sentence"] == "食べて"
      assert example["reading"] == "たべて"
      assert example["meaning"] == "eat (te-form)"
      # Placeholder pattern element
      assert grammar_step.pattern_elements == [%{"type" => "literal", "text" => "—"}]

      assert text_step.step_type == "text"
      assert text_step.title == "Verb Groups"
      assert text_step.explanation_sections == ["Verbs are classified into three groups."]
      assert text_step.examples == []
      assert text_step.pattern_elements == []
    end

    test "splits text step description into paragraphs", %{user: user} do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "Intro",
            "description" => "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.",
            "examples" => [],
            "step_type" => "text"
          }
        ]
      }

      assert {:ok, lesson} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(data, %{}, user.id)

      steps = Content.list_grammar_lesson_steps(lesson.id)
      step = hd(steps)
      assert step.explanation_sections == ["First paragraph.", "Second paragraph.", "Third paragraph."]
    end

    test "uses AI title when no custom title provided", %{user: user} do
      data = %{
        "title" => "IV. Grammar Notes",
        "sections" => [
          %{
            "number" => 1,
            "title" => "Section",
            "description" => "desc",
            "examples" => [],
            "step_type" => "text"
          }
        ]
      }

      assert {:ok, lesson} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(data, %{}, user.id)

      assert lesson.title == "IV. Grammar Notes"
    end

    test "uses default title when no title available", %{user: user} do
      data = %{
        "sections" => [
          %{
            "number" => 1,
            "title" => "Section",
            "description" => "desc",
            "examples" => [],
            "step_type" => "text"
          }
        ]
      }

      assert {:ok, lesson} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(data, %{}, user.id)

      assert lesson.title == "Grammar lesson from image — change the name"
    end

    test "handles up to 5 examples per grammar step", %{user: user} do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "V て-form",
            "description" => "desc",
            "examples" => Enum.map(1..6, fn i ->
              %{"sentence" => "s#{i}", "reading" => "r#{i}", "meaning" => "m#{i}"}
            end),
            "step_type" => "grammar"
          }
        ]
      }

      assert {:ok, lesson} =
               GrammarImageBuilder.build_lesson_from_extracted_grammar(data, %{}, user.id)

      steps = Content.list_grammar_lesson_steps(lesson.id)
      step = hd(steps)
      assert length(step.examples) == 5
    end
  end
end
