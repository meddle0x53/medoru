defmodule Medoru.AI.VocabularyParser do
  @moduledoc """
  Processes raw extracted vocabulary from AI into clean, structured data.

  The AI is prompted to return dictionary forms with kanji, but this module
  serves as a safety net: it handles any remaining ます-forms and ensures
  notes are built from verb group info.
  """

  @doc """
  Takes a list of raw word maps from AI and returns cleaned word maps.

  Each output map has:
  - text: dictionary form with kanji when available
  - reading: kana reading (converted from masu-form if needed)
  - meaning: English meaning
  - word_type: normalized word type
  - verb_group: "I", "II", "III", or nil
  - notes: description of verb group and original form
  """
  def parse_extracted_words(words) when is_list(words) do
    words
    |> Enum.map(&parse_single_word/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_extracted_words(_), do: []

  defp parse_single_word(word) when is_map(word) do
    text = word["text"] || ""
    reading = word["reading"] || ""
    meaning = word["meaning"] || ""
    word_type = normalize_word_type(word["word_type"])
    verb_group = normalize_verb_group(word["verb_group"])
    image_text = word["image_text"] || text

    # Safety net: convert masu-form to dictionary form if AI didn't
    {text, reading, verb_group} =
      if verb_group && String.ends_with?(text, "ます") do
        {
          convert_to_dictionary_form(text, verb_group),
          maybe_convert_reading(reading, verb_group),
          verb_group
        }
      else
        {text, reading, verb_group}
      end

    # Safety net: build notes from verb group if missing
    raw_notes = word["notes"]
    notes = if raw_notes in [nil, ""], do: build_notes(image_text, verb_group), else: raw_notes

    %{
      "text" => text,
      "image_text" => image_text,
      "reading" => reading,
      "meaning" => meaning,
      "word_type" => word_type,
      "verb_group" => verb_group,
      "notes" => notes
    }
  end

  defp parse_single_word(_), do: nil

  # --- Dictionary form conversion (safety net) ---

  defp maybe_convert_reading(reading, verb_group) do
    if String.ends_with?(reading, "ます") do
      convert_to_dictionary_form(reading, verb_group)
    else
      reading
    end
  end

  defp convert_to_dictionary_form(masu_form, "III") do
    stem = String.replace_suffix(masu_form, "ます", "")

    cond do
      stem == "き" -> "くる"
      stem == "来" -> "来る"
      stem == "する" -> "する"
      String.ends_with?(stem, "し") ->
        # 勉強します → 勉強し → 勉強する
        String.replace_suffix(stem, "し", "する")
      true -> stem <> "する"
    end
  end

  defp convert_to_dictionary_form(masu_form, "II") do
    String.replace_suffix(masu_form, "ます", "る")
  end

  defp convert_to_dictionary_form(masu_form, "I") do
    stem = String.replace_suffix(masu_form, "ます", "")

    last_kana = String.last(stem) || ""

    case last_kana do
      "い" -> String.replace_suffix(stem, "い", "う")
      "き" -> String.replace_suffix(stem, "き", "く")
      "ぎ" -> String.replace_suffix(stem, "ぎ", "ぐ")
      "し" -> String.replace_suffix(stem, "し", "す")
      "ち" -> String.replace_suffix(stem, "ち", "つ")
      "に" -> String.replace_suffix(stem, "に", "ぬ")
      "ひ" -> String.replace_suffix(stem, "ひ", "ふ")
      "び" -> String.replace_suffix(stem, "び", "ぶ")
      "み" -> String.replace_suffix(stem, "み", "む")
      "り" -> String.replace_suffix(stem, "り", "る")
      "え" -> String.replace_suffix(stem, "え", "う")
      "け" -> String.replace_suffix(stem, "け", "く")
      "げ" -> String.replace_suffix(stem, "げ", "ぐ")
      "せ" -> String.replace_suffix(stem, "せ", "す")
      "て" -> String.replace_suffix(stem, "て", "つ")
      "ね" -> String.replace_suffix(stem, "ね", "ぬ")
      "へ" -> String.replace_suffix(stem, "へ", "ふ")
      "べ" -> String.replace_suffix(stem, "べ", "ぶ")
      "め" -> String.replace_suffix(stem, "め", "む")
      "れ" -> String.replace_suffix(stem, "れ", "る")
      _ -> masu_form
    end
  end

  defp convert_to_dictionary_form(masu_form, _), do: masu_form

  # --- Notes builder ---

  defp build_notes(_image_text, nil), do: ""
  defp build_notes(_image_text, ""), do: ""

  defp build_notes(image_text, verb_group) when is_binary(verb_group) do
    base = "Group #{verb_group} verb"

    if image_text != "" and String.ends_with?(image_text, "ます") do
      "#{base} (from: #{image_text})"
    else
      base
    end
  end

  defp build_notes(_, _), do: ""

  # --- Normalization ---

  defp normalize_word_type(nil), do: "other"

  defp normalize_word_type(type) when is_binary(type) do
    normalized = String.downcase(String.trim(type))
    valid_types = ["noun", "verb", "adjective", "adverb", "particle", "pronoun", "counter", "expression", "other"]

    if normalized in valid_types do
      normalized
    else
      "other"
    end
  end

  defp normalize_word_type(_), do: "other"

  defp normalize_verb_group(nil), do: nil

  defp normalize_verb_group(group) when is_binary(group) do
    trimmed = String.trim(group)

    if trimmed in ["I", "II", "III"] do
      trimmed
    else
      nil
    end
  end

  defp normalize_verb_group(_), do: nil
end
