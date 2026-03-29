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

  alias Medoru.Content.{Word, WordConjugation, WordClass, WordClassMembership}
  alias Medoru.Repo

  import Ecto.Query

  # Contraction rules: when a form is followed by a specific expression,
  # the form may be contracted (e.g., ない-form drops い like い-adjectives)
  @contraction_rules %{
    "nai-form" => %{
      # い is dropped from the end, so we add back "ない" to reconstruct the full form
      # The contracted form "飲ま" + "ない" = "飲まない"
      add_suffix: "ない",
      # Common expressions that trigger this contraction
      expressions: ["なければ", "なくて", "ないで"]
    }
  }

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
  def validate_sentence(sentence, pattern_elements)
      when is_binary(sentence) and is_list(pattern_elements) do
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
    # If pattern was empty from start (nothing matched), require exact match
    # Otherwise, allow remaining text (suffix) after the pattern
    if breakdown == [] do
      {:error, %{position: String.length(remaining), expected: "end of sentence", got: remaining}}
    else
      {:ok, breakdown}
    end
  end

  defp do_validate(remaining, [element | rest], breakdown) do
    # Get the next element if it's a literal (for contraction detection)
    next_element = List.first(rest)

    case match_element(remaining, element, next_element) do
      {:ok, matched, new_remaining} ->
        do_validate(new_remaining, rest, [matched | breakdown])

      {:ok_with_skipped, matched, new_remaining, skipped_breakdown} ->
        # Prepend skipped text (if any) then the matched element
        full_breakdown = Enum.reverse(skipped_breakdown) ++ [matched | breakdown]
        do_validate(new_remaining, rest, full_breakdown)

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

  defp match_element(remaining, %{"type" => "literal", "text" => literal}, _next) do
    # Normalize literal by removing spaces for comparison
    normalized_literal = String.replace(literal, ~r/\s+/, "")

    if String.starts_with?(remaining, normalized_literal) do
      matched = %{
        text: literal,
        type: "literal",
        form: nil,
        meaning: element_meaning(literal)
      }

      new_remaining = String.slice(remaining, String.length(normalized_literal)..-1//1) || ""
      {:ok, matched, new_remaining}
    else
      {:error,
       %{position: 0, expected: "literal: #{literal}", got: String.slice(remaining, 0..5)}}
    end
  end

  defp match_element(remaining, %{"type" => "word_slot"} = slot, next_element) do
    word_type = slot["word_type"]
    # Support both "form" (single string) and "forms" (list) for backward compatibility
    allowed_forms =
      cond do
        slot["form"] -> [slot["form"]]
        slot["forms"] -> slot["forms"]
        true -> []
      end

    # For particles, use exact matching (not "anywhere" search)
    result =
      if word_type == "particle" do
        find_matching_particle(remaining, allowed_forms)
      else
        find_matching_word_anywhere(remaining, word_type, allowed_forms, nil)
      end

    case result do
      nil ->
        # Try contraction matching if next element is a literal (only for verbs)
        case try_contraction_match(remaining, word_type, allowed_forms, next_element) do
          nil ->
            if slot["optional"] do
              :optional_no_match
            else
              expected = build_expected_message(word_type, allowed_forms, nil)
              got = String.slice(remaining, 0, min(5, String.length(remaining)))
              {:error, %{position: 0, expected: expected, got: got}}
            end

          {matched_text, word_info, skipped_text} ->
            matched = %{
              text: matched_text,
              type: word_type,
              form: word_info.form,
              word_id: word_info[:word_id]
            }

            breakdown =
              if skipped_text && skipped_text != "" do
                [%{text: skipped_text, type: "skipped", form: nil}]
              else
                []
              end

            new_remaining =
              String.slice(remaining, String.length(skipped_text || "") + String.length(matched_text)..-1//1) ||
                ""

            {:ok_with_skipped, matched, new_remaining, breakdown}
        end

      {matched_text, word_info, skipped_text} ->
        matched = %{
          text: matched_text,
          type: word_type,
          form: word_info.form,
          word_id: word_info[:word_id]
        }

        # Include skipped text in breakdown if any
        breakdown =
          if skipped_text && skipped_text != "" do
            [%{text: skipped_text, type: "skipped", form: nil}]
          else
            []
          end

        new_remaining =
          String.slice(remaining, String.length(skipped_text || "") + String.length(matched_text)..-1//1) ||
            ""

        {:ok_with_skipped, matched, new_remaining, breakdown}
    end
  end

  defp match_element(remaining, %{"type" => "word_class"} = slot, _next) do
    word_class_id = slot["word_class_id"]

    if is_nil(word_class_id) do
      if slot["optional"] do
        :optional_no_match
      else
        {:error, %{position: 0, expected: "word class", got: String.slice(remaining, 0, 5)}}
      end
    else
      # Get word class name from ID
      word_class_name = get_word_class_name(word_class_id)

      # Try to find any word in this class
      case find_word_by_class(remaining, word_class_id) do
        nil ->
          if slot["optional"] do
            :optional_no_match
          else
            expected = "word from class: #{word_class_name}"
            got = String.slice(remaining, 0, min(5, String.length(remaining)))
            {:error, %{position: 0, expected: expected, got: got}}
          end

        {matched_text, word_info} ->
          matched = %{
            text: matched_text,
            type: word_info.word_type,
            word_class: word_class_name,
            word_id: word_info.word_id
          }

          new_remaining = String.slice(remaining, String.length(matched_text)..-1//1) || ""
          {:ok, matched, new_remaining}
      end
    end
  end

  defp match_element(_, _, _),
    do: {:error, %{position: 0, expected: "valid pattern element", got: "invalid"}}

  # Finds a matching particle - particles match exactly at the start or anywhere
  # Returns {matched_text, word_info, skipped_text} or nil
  defp find_matching_particle(sentence, allowed_forms) do
    sentence_len = String.length(sentence)

    # Try each starting position
    Enum.find_value(0..(sentence_len - 1), fn start_pos ->
      remaining = String.slice(sentence, start_pos..-1//1)
      skipped = String.slice(sentence, 0, start_pos)

      # Check if the remaining text starts with any of the allowed particle forms
      Enum.find_value(allowed_forms, fn particle ->
        if String.starts_with?(remaining, particle) do
          # Particle matched - return with a dummy word_info since particles
          # don't have word entries in the database
          {particle, %{form: particle}, skipped}
        else
          nil
        end
      end)
    end)
  end

  # Searches for a matching word anywhere in the sentence, not just at the start
  # Returns {matched_text, word_info, skipped_text} or nil
  defp find_matching_word_anywhere(sentence, word_type, allowed_forms, word_class) do
    max_len = min(String.length(sentence), 10)
    forms_list = allowed_forms || []
    sentence_len = String.length(sentence)

    # Try each starting position in the sentence
    Enum.find_value(0..(sentence_len - 1), fn start_pos ->
      # Get substring starting at this position
      remaining = String.slice(sentence, start_pos..-1//1)
      skipped = String.slice(sentence, 0, start_pos)

      # Try different lengths from this position
      Enum.find_value(max_len..1//-1, fn len ->
        candidate = String.slice(remaining, 0, len)

        # Check dictionary form
        dictionary_match = lookup_dictionary_form(candidate, word_type, word_class)

        if dictionary_match && (forms_list == [] || "dictionary" in forms_list) do
          {candidate, %{word_id: dictionary_match.id, form: "dictionary"}, skipped}
        else
          # Check conjugated forms
          conjugated_match = lookup_conjugated_form(candidate, word_type, forms_list, word_class)

          if conjugated_match do
            {candidate, conjugated_match, skipped}
          else
            nil
          end
        end
      end)
    end)
  end

  # Tries to match a word with contraction (e.g., ない-form dropping い)
  # Returns {matched_text, word_info, skipped_text} or nil
  defp try_contraction_match(_remaining, _word_type, _allowed_forms, nil), do: nil

  defp try_contraction_match(remaining, word_type, allowed_forms, next_element) do
    if next_element["type"] != "literal" do
      nil
    else
      # Normalize next text by removing spaces
      next_text = String.replace(next_element["text"], ~r/\s+/, "")
      try_contraction_for_forms(remaining, word_type, allowed_forms, next_text)
    end
  end

  defp try_contraction_for_forms(_remaining, _word_type, [], _next_text), do: nil

  defp try_contraction_for_forms(remaining, word_type, [form | rest], next_text) do
    case @contraction_rules[form] do
      nil ->
        try_contraction_for_forms(remaining, word_type, rest, next_text)

      %{add_suffix: suffix, expressions: exprs} ->
        # Check if next_text starts with any contraction-triggering expression
        case Enum.find(exprs, &String.starts_with?(next_text, &1)) do
          nil ->
            try_contraction_for_forms(remaining, word_type, rest, next_text)

          expr ->
            # The contracted form ends where the expression begins
            # Look for words where (candidate <> suffix) matches the full conjugation
            case find_contracted_form(remaining, word_type, form, suffix, expr) do
              nil -> try_contraction_for_forms(remaining, word_type, rest, next_text)
              result -> result
            end
        end
    end
  end

  # Finds a word in contracted form (e.g., "飲ま" matching ない-form of "飲む")
  defp find_contracted_form(sentence, word_type, form, suffix, expr) do
    sentence_len = String.length(sentence)

    # Try each starting position
    Enum.find_value(0..(sentence_len - 1), fn start_pos ->
      remaining = String.slice(sentence, start_pos..-1//1)
      skipped = String.slice(sentence, 0, start_pos)

      # The remaining must start with the expression or have text before it
      # The contracted form is the text before the expression starts
      case find_expression_position(remaining, expr) do
        nil ->
          nil

        pos ->
          # Extract the candidate (text before expression)
          candidate = String.slice(remaining, 0, pos)

          # Reconstruct the full form by adding back the dropped suffix
          full_form = candidate <> suffix

          # Check if this full form exists in our conjugations
          case lookup_conjugated_form(full_form, word_type, [form], nil) do
            nil -> nil
            word_info -> {candidate, word_info, skipped}
          end
      end
    end)
  end

  # Finds where the expression starts in the text
  defp find_expression_position(text, expr) do
    if String.starts_with?(text, expr) do
      0
    else
      # Look for the expression anywhere in the first 15 chars
      len = min(String.length(text), 15)

      Enum.find_value(1..len, fn pos ->
        suffix = String.slice(text, pos..-1//1)

        if String.starts_with?(suffix, expr) do
          pos
        else
          nil
        end
      end)
    end
  end

  defp lookup_dictionary_form(text, word_type, word_class) do
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
    # First try matching against conjugated_form (kanji)
    result = do_lookup_conjugated_form(text, word_type, allowed_forms, word_class, :conjugated_form)

    # If no match, try matching against reading (kana)
    if result do
      result
    else
      do_lookup_conjugated_form(text, word_type, allowed_forms, word_class, :reading)
    end
  end

  defp do_lookup_conjugated_form(text, word_type, allowed_forms, word_class, field) do
    query =
      WordConjugation
      |> join(:inner, [wc], w in assoc(wc, :word))
      |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
      |> where([wc, w, gf], w.word_type == ^word_type)

    # Add field filter based on which field we're checking
    query =
      case field do
        :conjugated_form -> where(query, [wc, _w, _gf], wc.conjugated_form == ^text)
        :reading -> where(query, [wc, _w, _gf], wc.reading == ^text)
      end

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

    query
    |> select([wc, w, gf], %{
      word_id: w.id,
      form: gf.name
    })
    |> limit(1)
    |> Repo.one()
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

  # Helper functions for word_class element type

  defp get_word_class_name(word_class_id) do
    WordClass
    |> where([wc], wc.id == ^word_class_id)
    |> select([wc], wc.name)
    |> Repo.one() || "unknown"
  end

  defp find_word_by_class(sentence, word_class_id) do
    # Try different lengths from longest to shortest
    max_len = min(String.length(sentence), 10)

    Enum.find_value(max_len..1//-1, fn len ->
      candidate = String.slice(sentence, 0, len)

      # Look for a word that:
      # 1. Matches the text
      # 2. Belongs to the specified word class
      result =
        Word
        |> join(:inner, [w], wcm in WordClassMembership, on: wcm.word_id == w.id)
        |> where([w, wcm], w.text == ^candidate and wcm.word_class_id == ^word_class_id)
        |> select([w], %{word_id: w.id, word_type: w.word_type})
        |> limit(1)
        |> Repo.one()

      if result do
        {candidate, result}
      else
        nil
      end
    end)
  end
end
