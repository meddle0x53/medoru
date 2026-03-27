defmodule Medoru.Grammar.Validator do
  @moduledoc """
  Validates Japanese sentences against grammar patterns.

  ## Pattern Elements

  Pattern elements are maps with:
  - `"type"`: "word_slot" or "literal"
  - `"word_type"`: "verb", "noun", "adjective" (for word_slot)
  - `"forms"`: List of allowed forms, e.g., ["te-form", "nai-form"]
  - `"word_class"`: Optional word class, e.g., "time", "place"
  - `"optional"`: Boolean, if true this element can be skipped
  - `"text"`: The literal text (for literal type)

  ## Examples

      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]},
        %{"type" => "literal", "text" => "まえに、"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      validate_sentence("食べるまえに、手を洗います。", pattern)
      # => {:ok, [%{text: "食べる", ...}, %{text: "まえに、", ...}, %{text: "手を洗います", ...}]}
  """

  alias Medoru.Grammar.{Tokenizer, FormDetector}

  @doc """
  Validates if a sentence matches the grammar pattern.

  ## Returns

    - `{:ok, breakdown}` - Sentence is valid with word breakdown
    - `{:error, reason}` - Validation failed with specific reason

  ## Examples

      iex> pattern = [
      ...>   %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]},
      ...>   %{"type" => "literal", "text" => "まえに、"},
      ...>   %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ...> ]
      iex> validate_sentence("食べるまえに、手を洗います。", pattern)
      {:ok, [%{text: "食べる", type: "verb", form: "dictionary"}, ...]}
  """
  def validate_sentence(sentence, pattern_elements) when is_binary(sentence) and is_list(pattern_elements) do
    normalized = normalize_input(sentence)

    case do_validate(normalized, pattern_elements, []) do
      {:ok, breakdown} -> {:ok, Enum.reverse(breakdown)}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_sentence(_, _), do: {:error, "Invalid input"}

  @doc """
  Validates with detailed error reporting for teachers.

  Returns a map with:
  - valid: boolean
  - breakdown: list of matched elements (if valid)
  - error_at: position where validation failed
  - expected: what was expected
  - got: what was found
  """
  def validate_with_details(sentence, pattern_elements) do
    case validate_sentence(sentence, pattern_elements) do
      {:ok, breakdown} ->
        %{valid: true, breakdown: breakdown}

      {:error, %{position: pos, expected: expected, got: got}} ->
        %{
          valid: false,
          error_at: pos,
          expected: expected,
          got: got,
          partial_breakdown: []
        }

      {:error, reason} ->
        %{valid: false, error: reason}
    end
  end

  # Private functions

  defp normalize_input(sentence) do
    sentence
    |> String.trim()
    |> String.replace(~r/\s+/, "")
  end

  defp do_validate("", [], breakdown), do: {:ok, breakdown}

  defp do_validate(remaining, [], breakdown) do
    # Check if remaining is just punctuation
    if String.match?(remaining, ~r/^[。、！？.,!?]*$/) do
      {:ok, breakdown}
    else
      {:error, %{position: String.length(remaining), expected: "end of sentence", got: remaining}}
    end
  end

  defp do_validate(remaining, [element | rest], breakdown) do
    case match_element(remaining, element) do
      {:ok, matched, new_remaining} ->
        do_validate(new_remaining, rest, [matched | breakdown])

      {:error, reason} ->
        if element["optional"] do
          # Skip optional element and continue
          do_validate(remaining, rest, breakdown)
        else
          {:error, reason}
        end

      :optional_no_match ->
        # Optional element didn't match, continue
        do_validate(remaining, rest, breakdown)
    end
  end

  defp match_element(remaining, %{"type" => "literal", "text" => literal}) do
    if String.starts_with?(remaining, literal) do
      matched = %{
        text: literal,
        type: "literal",
        form: nil,
        meaning: element_meaning(literal)
      }

      new_remaining = String.slice(remaining, String.length(literal)..-1) || ""
      {:ok, matched, new_remaining}
    else
      {:error, %{position: 0, expected: "literal: #{literal}", got: String.slice(remaining, 0..5)}}
    end
  end

  defp match_element(remaining, %{"type" => "word_slot"} = slot) do
    word_type = slot["word_type"]
    allowed_forms = slot["forms"] || []
    word_class = slot["word_class"]

    # Try to find a matching word
    case find_matching_word(remaining, word_type, allowed_forms, word_class) do
      nil ->
        if slot["optional"] do
          :optional_no_match
        else
          expected = build_expected_message(word_type, allowed_forms, word_class)
          got = String.slice(remaining, 0..min(5, String.length(remaining) - 1))
          {:error, %{position: 0, expected: expected, got: got}}
        end

      {matched_text, word_info} ->
        matched = %{
          text: matched_text,
          type: word_type,
          form: word_info.form,
          word_id: word_info.word_id,
          word_class: word_class
        }

        new_remaining = String.slice(remaining, String.length(matched_text)..-1) || ""
        {:ok, matched, new_remaining}
    end
  end

  defp match_element(_, _), do: {:error, %{position: 0, expected: "valid pattern element", got: "invalid"}}

  defp find_matching_word(sentence, word_type, allowed_forms, word_class) do
    # Try different lengths from longest to shortest
    max_len = min(String.length(sentence), 10)
    forms_list = allowed_forms || []

    Enum.find_value(max_len..1, fn len ->
      candidate = String.slice(sentence, 0, len)

      # Check dictionary form
      dictionary_match = lookup_dictionary_form(candidate, word_type, word_class)

      if dictionary_match && (forms_list == [] || "dictionary" in forms_list) do
        {candidate, %{word_id: dictionary_match.id, form: "dictionary"}}
      else
        # Check conjugated forms
        conjugated_match = lookup_conjugated_form(candidate, word_type, forms_list, word_class)

        if conjugated_match do
          {candidate, conjugated_match}
        else
          nil
        end
      end
    end)
  end

  defp lookup_dictionary_form(text, word_type, word_class) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Content.{Word, WordClassMembership}

    query =
      Word
      |> where([w], w.text == ^text and w.word_type == ^word_type)

    # Add word_class filter if specified
    query =
      if word_class do
        query
        |> join(:inner, [w], wcm in WordClassMembership, on: wcm.word_id == w.id)
        |> join(:inner, [_w, wcm], wc in "word_classes", on: wc.id == wcm.word_class_id)
        |> where([_w, _wcm, wc], wc.name == ^word_class)
      else
        query
      end

    query
    |> limit(1)
    |> Repo.one()
  end

  defp lookup_conjugated_form(text, word_type, allowed_forms, word_class) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Content.{WordConjugation, Word, GrammarForm, WordClassMembership}

    query =
      WordConjugation
      |> join(:inner, [wc], w in assoc(wc, :word))
      |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
      |> where([wc, w, gf], wc.conjugated_form == ^text and w.word_type == ^word_type)

    # Filter by allowed forms
    query =
      if allowed_forms != [] do
        where(query, [_wc, _w, gf], gf.name in ^allowed_forms)
      else
        query
      end

    # Add word_class filter if specified
    query =
      if word_class do
        query
        |> join(:inner, [_wc, w, _gf], wcm in WordClassMembership, on: wcm.word_id == w.id)
        |> join(:inner, [_wc, _w, _gf, wcm], wc in "word_classes", on: wc.id == wcm.word_class_id)
        |> where([_wc, _w, _gf, _wcm, wc], wc.name == ^word_class)
      else
        query
      end

    result =
      query
      |> select([wc, w, gf], %{
        word_id: w.id,
        form: gf.name
      })
      |> limit(1)
      |> Repo.one()

    result
  end

  defp build_expected_message(word_type, [], nil) do
    "#{word_type}"
  end

  defp build_expected_message(word_type, forms, nil) do
    form_str = Enum.join(forms, ", ")
    "#{word_type} (#{form_str} form)"
  end

  defp build_expected_message(word_type, forms, word_class) do
    form_str = if forms == [], do: "", else: " (#{Enum.join(forms, ", ")} form)"
    "#{word_class} #{word_type}#{form_str}"
  end

  defp element_meaning("まえに、"), do: "before"
  defp element_meaning("あとで、"), do: "after"
  defp element_meaning("とき、"), do: "when"
  defp element_meaning("ながら、"), do: "while"
  defp element_meaning(_), do: nil
end
