defmodule Medoru.Tests.ReadingAnswerValidator do
  @moduledoc """
  Validates user answers for reading comprehension text input questions.

  Validates both:
  - Meaning (English): Fuzzy match against accepted meanings
  - Kana Reading (Hiragana): Exact match with acceptable variations

  ## Validation Rules

  ### Meaning Validation
  - Case insensitive matching
  - Partial word matching (e.g., "eat" matches "to eat")
  - Common prefix/suffix stripping ("to ", "a ", "the ", "s")

  ### Kana Reading Validation
  - Exact match for most readings
  - Acceptable variations for long vowels
  """

  @doc """
  Validates both meaning and reading answers for a word.

  ## Parameters
    * `word` - The Word struct with meaning and reading
    * `meaning_answer` - User's English meaning answer
    * `reading_answer` - User's hiragana reading answer

  ## Returns
    `{:ok, %{meaning_correct: boolean, reading_correct: boolean}}` - Validation result

  ## Examples

      iex> validate_answer(word, "to eat", "たべる")
      {:ok, %{meaning_correct: true, reading_correct: true}}

  """
  def validate_answer(word, meaning_answer, reading_answer) do
    meaning_correct = validate_meaning(word.meaning, meaning_answer)
    reading_correct = validate_reading(word.reading, reading_answer)

    {:ok,
     %{
       meaning_correct: meaning_correct,
       reading_correct: reading_correct,
       both_correct: meaning_correct and reading_correct
     }}
  end

  @doc """
  Validates the meaning answer against the word's meaning.

  Uses fuzzy matching to accept variations:
  - Case insensitive
  - Partial word matches
  - Strips common prefixes/suffixes

  ## Examples

      iex> validate_meaning("to eat", "eat")
      true

      iex> validate_meaning("to drink", "drinking")
      true

  """
  def validate_meaning(correct_meaning, user_answer)
      when is_binary(correct_meaning) and is_binary(user_answer) do
    correct = normalize_text(correct_meaning)
    answer = normalize_text(user_answer)

    # Direct match
    # Answer is contained in correct meaning (e.g., "eat" in "to eat")
    # Correct meaning is contained in answer
    # Word-level overlap
    correct == answer or
      String.contains?(correct, answer) or
      String.contains?(answer, correct) or
      word_overlap?(correct, answer)
  end

  def validate_meaning(_, _), do: false

  @doc """
  Validates the reading answer against the word's reading.

  Accepts exact match and common kana variations:
  - Long vowel variations: ou/oo, ei/ee

  ## Examples

      iex> validate_reading("toukyou", "to-kyou")  # fictional example
      true

  """
  def validate_reading(correct_reading, user_answer)
      when is_binary(correct_reading) and is_binary(user_answer) do
    correct_normalized = normalize_kana(correct_reading)
    answer_normalized = normalize_kana(user_answer)

    # Direct normalized match
    # Generate all acceptable variations and check
    correct_normalized == answer_normalized or
      variations_match?(correct_reading, user_answer)
  end

  def validate_reading(_, _), do: false

  # Private functions

  # Normalize text for comparison (lowercase, trim)
  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> strip_common_prefixes()
  end

  # Strip common prefixes that don't change meaning
  defp strip_common_prefixes(text) do
    text
    |> String.replace_prefix("to ", "")
    |> String.replace_prefix("a ", "")
    |> String.replace_prefix("an ", "")
    |> String.replace_prefix("the ", "")
    |> String.replace_suffix("s", "")
  end

  # Check if there's significant word overlap
  defp word_overlap?(text1, text2) do
    words1 = String.split(text1, ~r/[\s,\/]+/)
    words2 = String.split(text2, ~r/[\s,\/]+/)

    # If significant portion of words match
    matches =
      Enum.count(words1, fn w1 ->
        Enum.any?(words2, fn w2 ->
          String.contains?(w1, w2) or String.contains?(w2, w1)
        end)
      end)

    matches > 0 and matches / length(words1) >= 0.5
  end

  # Normalize kana (convert to hiragana, standardize)
  defp normalize_kana(text) do
    text
    |> String.trim()
    |> to_hiragana()
  end

  # Convert katakana to hiragana for comparison
  defp to_hiragana(text) do
    text
    |> String.to_charlist()
    |> Enum.map(fn
      # Katakana to Hiragana conversion
      cp when cp >= 0x30A1 and cp <= 0x30F6 ->
        cp - 0x30A1 + 0x3041

      cp ->
        cp
    end)
    |> to_string()
  end

  # Check if two readings match with acceptable variations
  defp variations_match?(reading1, reading2) do
    # Generate variations for both and see if any match
    vars1 = generate_kana_variations(reading1)
    vars2 = generate_kana_variations(reading2)

    Enum.any?(vars1, fn v1 ->
      Enum.any?(vars2, fn v2 -> v1 == v2 end)
    end)
  end

  # Generate acceptable variations of a kana reading
  # Uses actual hiragana characters for long vowel variations:
  # - う (u) in long vowels: おう <-> おお, きょう <-> きょお
  # - い (i) in long vowels: えい <-> ええ
  defp generate_kana_variations(reading) do
    reading = to_hiragana(reading)

    # Generate variations by replacing all occurrences
    # う (u) can sometimes be replaced with the vowel it extends
    # い (i) can sometimes be replaced with え (e) in えい -> ええ
    variations = [
      reading,
      # おう -> おお variation (u replacing o)
      String.replace(reading, "おう", "おお"),
      String.replace(reading, "おお", "おう"),
      # こう -> こお variation (and similar for other consonants)
      String.replace(reading, "こう", "こお"),
      String.replace(reading, "こお", "こう"),
      String.replace(reading, "そう", "そお"),
      String.replace(reading, "そお", "そう"),
      String.replace(reading, "とう", "とお"),
      String.replace(reading, "とお", "とう"),
      String.replace(reading, "のう", "のお"),
      String.replace(reading, "のお", "のう"),
      String.replace(reading, "ほう", "ほお"),
      String.replace(reading, "ほお", "ほう"),
      String.replace(reading, "もう", "もお"),
      String.replace(reading, "もお", "もう"),
      String.replace(reading, "ろう", "ろお"),
      String.replace(reading, "ろお", "ろう"),
      # きょう -> きょお variation (kyou -> kyoo)
      String.replace(reading, "きょう", "きょお"),
      String.replace(reading, "きょお", "きょう"),
      String.replace(reading, "しょう", "しょお"),
      String.replace(reading, "しょお", "しょう"),
      String.replace(reading, "ちょう", "ちょお"),
      String.replace(reading, "ちょお", "ちょう"),
      String.replace(reading, "にょう", "にょお"),
      String.replace(reading, "にょお", "にょう"),
      String.replace(reading, "ひょう", "ひょお"),
      String.replace(reading, "ひょお", "ひょう"),
      String.replace(reading, "みょう", "みょお"),
      String.replace(reading, "みょお", "みょう"),
      String.replace(reading, "りょう", "りょお"),
      String.replace(reading, "りょお", "りょう"),
      # えい -> ええ variation
      String.replace(reading, "えい", "ええ"),
      String.replace(reading, "ええ", "えい"),
      String.replace(reading, "けい", "けえ"),
      String.replace(reading, "けえ", "けい"),
      String.replace(reading, "せい", "せえ"),
      String.replace(reading, "せえ", "せい"),
      String.replace(reading, "てい", "てえ"),
      String.replace(reading, "てえ", "てい"),
      String.replace(reading, "ねい", "ねえ"),
      String.replace(reading, "ねえ", "ねい"),
      String.replace(reading, "へい", "へえ"),
      String.replace(reading, "へえ", "へい"),
      String.replace(reading, "めい", "めえ"),
      String.replace(reading, "めえ", "めい"),
      String.replace(reading, "れい", "れえ"),
      String.replace(reading, "れえ", "れい")
    ]

    Enum.uniq(variations)
  end

  @doc """
  Generates a hint for the meaning answer.

  Returns the first letter(s) of the correct answer.

  ## Examples

      iex> meaning_hint("to eat")
      "t..."

  """
  def meaning_hint(correct_meaning) do
    correct_meaning
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "..."
      first -> first <> "..."
    end
  end

  @doc """
  Generates a hint for the reading answer.

  Returns the first kana of the correct reading.

  ## Examples

      iex> reading_hint("たべる")
      "た..."

  """
  def reading_hint(correct_reading) do
    correct_reading
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "..."
      first -> first <> "..."
    end
  end
end
