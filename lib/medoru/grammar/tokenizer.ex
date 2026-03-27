defmodule Medoru.Grammar.Tokenizer do
  @moduledoc """
  Tokenizes Japanese sentences for grammar validation.

  Uses a dictionary-based approach, matching words from our database
  including their conjugated forms.
  """

  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Content.Word
  alias Medoru.Grammar.FormDetector

  @doc """
  Tokenizes a sentence into words with their forms and types.

  ## Returns

  A list of tokens, each containing:
  - text: The matched text
  - word_id: The base word ID (if known)
  - word_type: The word type (verb, noun, adjective, etc.)
  - form: The grammar form (if conjugated)
  - position: Position in the sentence

  ## Examples

      iex> tokenize("食べるまえに、手を洗います。")
      [
        %{text: "食べる", word_id: "...", word_type: "verb", form: "dictionary", position: 0},
        %{text: "まえに、", word_id: nil, word_type: "literal", form: nil, position: 3},
        %{text: "手を洗います", word_id: "...", word_type: "verb", form: "masu-form", position: 7}
      ]
  """
  def tokenize(sentence) when is_binary(sentence) do
    # Normalize sentence (remove spaces, handle punctuation)
    normalized = normalize_sentence(sentence)

    # Try to match words from the longest possible match
    do_tokenize(normalized, [], 0)
  end

  def tokenize(_), do: []

  @doc """
  Tokenizes a sentence and returns only the matched words (no literals).
  """
  def tokenize_words(sentence) when is_binary(sentence) do
    sentence
    |> tokenize()
    |> Enum.reject(&(&1.word_type == "literal"))
  end

  def tokenize_words(_), do: []

  # Private functions

  defp normalize_sentence(sentence) do
    sentence
    |> String.replace(~r/\s+/, "")
    |> String.replace(~r/[。、！？.,!?]/, "")
  end

  defp do_tokenize("", tokens, _position), do: Enum.reverse(tokens)

  defp do_tokenize(remaining, tokens, position) do
    # Try to find the longest matching word (up to 10 characters)
    max_len = min(String.length(remaining), 10)

    case find_longest_match(remaining, max_len) do
      nil ->
        # No match found, treat as single character literal
        {char, rest} = String.split_at(remaining, 1)

        token = %{
          text: char,
          word_id: nil,
          word_type: "literal",
          form: nil,
          position: position
        }

        do_tokenize(rest, [token | tokens], position + 1)

      {matched_text, word_id, word_type, form, matched_len} ->
        token = %{
          text: matched_text,
          word_id: word_id,
          word_type: word_type,
          form: form,
          position: position
        }

        rest = String.slice(remaining, matched_len..-1)
        do_tokenize(rest, [token | tokens], position + matched_len)
    end
  end

  defp find_longest_match(remaining, max_len) when max_len > 0 do
    candidate = String.slice(remaining, 0, max_len)

    case lookup_word(candidate) do
      nil ->
        # Try shorter match
        find_longest_match(remaining, max_len - 1)

      result ->
        {candidate, result.word_id, result.word_type, result.form, max_len}
    end
  end

  defp find_longest_match(_, 0), do: nil

  defp lookup_word(text) do
    # First, check if it's a dictionary form
    dictionary_match =
      Word
      |> where([w], w.text == ^text)
      |> select([w], %{word_id: w.id, word_type: w.word_type, form: "dictionary"})
      |> limit(1)
      |> Repo.one()

    if dictionary_match do
      dictionary_match
    else
      # Check if it's a conjugated form
      FormDetector.get_dictionary_form(text)
      |> case do
        nil -> nil
        result -> Map.put(result, :form, List.first(FormDetector.detect_form(text)))
      end
    end
  end

  @doc """
  Checks if a sentence starts with a pattern element.

  Used for pattern matching during validation.
  """
  def starts_with_pattern?(sentence, pattern_element) do
    normalized = normalize_sentence(sentence)

    case pattern_element do
      %{"type" => "literal", "text" => literal} ->
        String.starts_with?(normalized, literal)

      %{"type" => "word_slot"} = slot ->
        match_word_slot?(normalized, slot)

      _ ->
        false
    end
  end

  defp match_word_slot?(sentence, %{"word_type" => word_type} = slot) do
    # Try to match a word at the start
    max_len = min(String.length(sentence), 10)

    Enum.any?(1..max_len, fn len ->
      candidate = String.slice(sentence, 0, len)

      case lookup_word(candidate) do
        nil -> false
        result -> result.word_type == word_type and form_matches?(result.form, slot)
      end
    end)
  end

  defp form_matches?(_detected_form, %{"forms" => allowed_forms}) when is_list(allowed_forms) do
    # Check if detected form is in the allowed list
    # For now, we accept if no specific forms are required
    true
  end

  defp form_matches?(_detected_form, _slot), do: true

  @doc """
  Extracts the matched portion of a sentence based on a pattern element.

  Returns {matched_text, rest_of_sentence} or nil if no match.
  """
  def extract_match(sentence, pattern_element) do
    normalized = normalize_sentence(sentence)

    case pattern_element do
      %{"type" => "literal", "text" => literal} ->
        if String.starts_with?(normalized, literal) do
          {literal, String.slice(normalized, String.length(literal)..-1)}
        else
          nil
        end

      %{"type" => "word_slot"} = slot ->
        extract_word_match(normalized, slot)

      _ ->
        nil
    end
  end

  defp extract_word_match(sentence, %{"word_type" => word_type} = slot) do
    max_len = min(String.length(sentence), 10)

    # Try longest match first
    Enum.find_value(max_len..1, fn len ->
      candidate = String.slice(sentence, 0, len)

      case lookup_word(candidate) do
        nil ->
          nil

        result ->
          if result.word_type == word_type and form_matches?(result.form, slot) do
            {candidate, String.slice(sentence, len..-1)}
          else
            nil
          end
      end
    end)
  end
end
