defmodule Medoru.AI.GrammarParserTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.GrammarParser

  describe "parse_extracted_grammar/1" do
    test "classifies grammar steps by title markers" do
      data = %{
        "title" => "Grammar Notes",
        "sections" => [
          %{
            "number" => 1,
            "title" => "V て-form",
            "description" => "The te-form of verbs.",
            "examples" => [
              %{"sentence" => "食べて", "reading" => "たべて", "meaning" => "eat (te-form)"}
            ],
            "is_grammar_pattern" => true
          },
          %{
            "number" => 2,
            "title" => "Verb Groups",
            "description" => "Verbs are classified into three groups.",
            "examples" => [],
            "is_grammar_pattern" => false
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      assert result["title"] == "Grammar Notes"

      [grammar_step, text_step] = result["sections"]
      assert grammar_step["step_type"] == "grammar"
      assert grammar_step["title"] == "V て-form"
      assert length(grammar_step["examples"]) == 1

      assert text_step["step_type"] == "text"
      assert text_step["title"] == "Verb Groups"
      assert text_step["examples"] == []
    end

    test "detects grammar patterns by regex when is_grammar_pattern is nil" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "N が V",
            "description" => "Subject marked with が.",
            "examples" => [],
            "is_grammar_pattern" => nil
          },
          %{
            "number" => 2,
            "title" => "Adjective Conjugation",
            "description" => "I-adjectives...",
            "examples" => [],
            "is_grammar_pattern" => nil
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      [step1, step2] = result["sections"]
      assert step1["step_type"] == "grammar"
      assert step2["step_type"] == "grammar"
    end

    test "text steps have no examples even if AI provided them" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "Introduction",
            "description" => "This is an intro.",
            "examples" => [
              %{"sentence" => "hello", "reading" => "hello", "meaning" => "hello"}
            ],
            "is_grammar_pattern" => false
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      step = hd(result["sections"])
      assert step["step_type"] == "text"
      assert step["examples"] == []
    end

    test "limits examples to 5" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "V て-form",
            "description" => "desc",
            "examples" => Enum.map(1..10, fn i ->
              %{"sentence" => "s#{i}", "reading" => "r#{i}", "meaning" => "m#{i}"}
            end),
            "is_grammar_pattern" => true
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      step = hd(result["sections"])
      assert length(step["examples"]) == 5
    end

    test "filters out empty examples" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "number" => 1,
            "title" => "V て-form",
            "description" => "desc",
            "examples" => [
              %{"sentence" => "", "reading" => "", "meaning" => ""},
              %{"sentence" => "食べて", "reading" => "たべて", "meaning" => "eat"}
            ],
            "is_grammar_pattern" => true
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      step = hd(result["sections"])
      assert length(step["examples"]) == 1
    end

    test "handles missing data gracefully" do
      assert GrammarParser.parse_extracted_grammar(nil) == %{
        "title" => "Grammar Lesson",
        "sections" => []
      }

      assert GrammarParser.parse_extracted_grammar(%{}) == %{
        "title" => "Grammar Lesson",
        "sections" => []
      }
    end

    test "handles sections without number" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{
            "title" => "V て-form",
            "description" => "desc",
            "examples" => [],
            "is_grammar_pattern" => true
          }
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      step = hd(result["sections"])
      assert step["number"] == 0
    end

    test "numbered variable markers like V1, N2, A1 are detected by regex" do
      data = %{
        "title" => "Test",
        "sections" => [
          %{"number" => 1, "title" => "V1 + N2", "description" => "desc", "examples" => [], "is_grammar_pattern" => nil},
          %{"number" => 2, "title" => "A1 + い", "description" => "desc", "examples" => [], "is_grammar_pattern" => nil}
        ]
      }

      result = GrammarParser.parse_extracted_grammar(data)
      [step1, step2] = result["sections"]
      assert step1["step_type"] == "grammar"
      assert step2["step_type"] == "grammar"
    end
  end
end
