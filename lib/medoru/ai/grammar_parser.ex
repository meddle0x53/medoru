defmodule Medoru.AI.GrammarParser do
  @moduledoc """
  Processes raw extracted grammar sections from AI into clean, structured data.

  Determines whether each section should be a "grammar" step or a "text" step
  based on the section title, and normalizes example structures.
  """

  # Regex to detect grammar pattern markers in titles
  # Matches: V, N, A, Noun, Verb, Adjective, Adverb, V1, N2, A1, etc.
  @grammar_pattern_regex ~r/\b(V|N|A|Noun|Verb|Adjective|Adverb|V\d+|N\d+|A\d+)\b/i

  @doc """
  Takes a map with "title" and "sections" from AI and returns cleaned data.

  ## Output structure

    %{
      "title" => "page title",
      "sections" => [
        %{
          "number" => 1,
          "title" => "section title",
          "description" => "full text",
          "examples" => [...],
          "step_type" => "grammar" | "text"
        }
      ]
    }
  """
  def parse_extracted_grammar(%{"title" => title, "sections" => sections}) do
    %{
      "title" => title || "Grammar Lesson",
      "sections" => Enum.map(sections, &parse_section/1) |> Enum.reject(&is_nil/1)
    }
  end

  def parse_extracted_grammar(%{"sections" => sections}) do
    parse_extracted_grammar(%{"title" => "Grammar Lesson", "sections" => sections})
  end

  def parse_extracted_grammar(_),
    do: %{
      "title" => "Grammar Lesson",
      "sections" => []
    }

  defp parse_section(%{"title" => title} = section) do
    description = String.trim(section["description"] || "")
    examples = normalize_examples(section["examples"] || [])

    # Determine step type based on title
    # Trust AI's is_grammar_pattern when explicitly set, otherwise fall back to regex
    is_grammar =
      case section["is_grammar_pattern"] do
        nil -> has_grammar_pattern_marker?(title)
        val -> !!val
      end

    step_type = if is_grammar, do: "grammar", else: "text"

    %{
      "number" => section["number"] || 0,
      "title" => String.trim(title),
      "description" => description,
      "examples" => examples,
      "step_type" => step_type
    }
  end

  defp parse_section(_), do: nil

  defp has_grammar_pattern_marker?(title) when is_binary(title) do
    Regex.match?(@grammar_pattern_regex, title)
  end

  defp has_grammar_pattern_marker?(_), do: false

  defp normalize_examples(examples) when is_list(examples) do
    examples
    |> Enum.map(&normalize_example/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(5)
  end

  defp normalize_examples(_), do: []

  defp normalize_example(%{"sentence" => s, "reading" => r, "meaning" => m}) do
    sentence = String.trim(s)
    reading = String.trim(r)
    meaning = String.trim(m)

    # Skip empty examples
    if sentence == "" and reading == "" and meaning == "" do
      nil
    else
      %{
        "sentence" => sentence,
        "reading" => reading,
        "meaning" => meaning,
        "meaning_bg" => "",
        "meaning_ja" => ""
      }
    end
  end

  defp normalize_example(_), do: nil
end
