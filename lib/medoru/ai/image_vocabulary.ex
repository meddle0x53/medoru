defmodule Medoru.AI.ImageVocabulary do
  @moduledoc """
  Extracts vocabulary from an image using OpenAI's Vision API.

  Given an image of a Japanese vocabulary page (e.g. textbook), this module
  sends the image to gpt-4o and returns a structured list of vocabulary entries
  with dictionary forms, readings, meanings, and verb group information.
  """

  alias Medoru.Content.Word

  @openai_chat_url "https://api.openai.com/v1/chat/completions"

  @extraction_prompt """
  Extract all Japanese vocabulary from this image.

  Include ALL of the following:
  - Single words (nouns, verbs, adjectives, adverbs, particles, pronouns, counters)
  - Katakana words and loanwords (e.g. アイスクリーム, カレー). For these, "text" and "reading" will usually be the same kana.
  - Expressions, set phrases, greetings, and interjections (e.g. おはようございます, どうぞよろしく[おねがいします]).
  - Multi-word phrases that appear as vocabulary items.

  For each item, return a JSON array of objects with these fields:
  - "text": the MAIN form of the word, WITH kanji when present.
    - For verbs: convert the ます-form to dictionary form, but KEEP any kanji.
      Example: if image shows "消します", text should be "消す" (not "けす").
      Example: if image shows "開けます", text should be "開ける" (not "あける").
      Example: if image shows "話します", text should be "話す" (not "はなす").
    - For nouns/adjectives: use the kanji form shown in the image.
    - For katakana or hiragana-only items with no kanji, set "text" to the kana form shown (same as "reading").
    - If an expression shows optional parts in brackets like [どうぞ]よろしく[ございます], include the brackets in "text".
  - "reading": ONLY hiragana/katakana (no kanji). This is the pronunciation.
    Example: for text "消す", reading should be "けす".
    Example: for text "電気", reading should be "でんき".
  - "image_text": the exact form as shown in the image (may include ます, kanji, brackets, etc.)
  - "meaning": English meaning
  - "word_type": noun, verb, adjective, adverb, particle, pronoun, counter, expression, or other
  - "verb_group": for verbs only — "I", "II", or "III". Null for non-verbs.

  CRITICAL: "text" must contain kanji when the original word uses kanji. "reading" must be pure kana.

  Return ONLY a JSON array. No markdown, no explanations.
  """

  @doc """
  Extracts vocabulary from an image binary.

  ## Options

    * `:model` - OpenAI model to use. Defaults to the configured model or "gpt-4o".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, [map]}` - List of extracted vocabulary entries
    * `{:error, String.t()}` - Error message
  """
  def extract_vocabulary(image_binary, opts \\ []) do
    model = Keyword.get(opts, :model, default_model())
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      base64_image = Base.encode64(image_binary)
      mime_type = detect_mime_type(image_binary)
      data_url = "data:#{mime_type};base64,#{base64_image}"

      call_vision_api(data_url, model, api_key, req_opts)
    end
  end

  defp detect_mime_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: "image/png"
  defp detect_mime_type(<<0xFF, 0xD8, _::binary>>), do: "image/jpeg"
  defp detect_mime_type(<<0x52, 0x49, 0x46, 0x46, _::binary>>), do: "image/webp"
  defp detect_mime_type(_), do: "image/jpeg"

  defp call_vision_api(data_url, model, api_key, req_opts) do
    body = %{
      model: model,
      messages: [
        %{
          role: "user",
          content: [
            %{type: "text", text: @extraction_prompt},
            %{type: "image_url", image_url: %{url: data_url}}
          ]
        }
      ],
      temperature: 0.1
    }

    opts =
      [
        headers: [{"authorization", "Bearer #{api_key}"}],
        json: body,
        receive_timeout: 60_000
      ] ++ req_opts

    case Req.post(@openai_chat_url, opts) do
      {:ok, %{status: 200, body: response_body}} ->
        parse_response(response_body)

      {:ok, %{status: status, body: response_body}} when is_map(response_body) ->
        error_message =
          get_in(response_body, ["error", "message"]) || "OpenAI API returned status #{status}"

        {:error, error_message}

      {:ok, %{status: status}} ->
        {:error, "OpenAI API returned status #{status}"}

      {:error, exception} ->
        {:error, "Request failed: #{Exception.message(exception)}"}
    end
  end

  defp parse_response(%{"choices" => [%{"message" => message} | _]}) do
    content = message["content"]

    cond do
      is_nil(content) or content == "" ->
        refusal = message["refusal"]

        if is_binary(refusal) and refusal != "" do
          {:error, "AI refused to process the image: #{refusal}"}
        else
          {:error, "AI returned empty response. The image may be unreadable or too large."}
        end

      true ->
        json_text = extract_json_from_text(content)

        case Jason.decode(json_text) do
          {:ok, %{"words" => words}} when is_list(words) ->
            {:ok, words |> Enum.map(&normalize_word/1) |> Enum.reject(&is_nil/1)}

          {:ok, words} when is_list(words) ->
            {:ok, words |> Enum.map(&normalize_word/1) |> Enum.reject(&is_nil/1)}

          {:ok, _} ->
            {:error, "OpenAI returned unexpected JSON structure"}

          {:error, decode_error} ->
            {:error, "Failed to parse OpenAI response: #{Exception.message(decode_error)}"}
        end
    end
  end

  defp parse_response(_) do
    {:error, "Unexpected response format from OpenAI API"}
  end

  defp extract_json_from_text(text) do
    text = String.trim(text)

    case Regex.run(~r/```(?:json)?\s*([\s\S]*?)\s*```/, text) do
      [_, inner] -> String.trim(inner)
      _ -> text
    end
  end

  defp normalize_word(word) when is_map(word) do
    verb_group = word["verb_group"]
    raw_text = word["text"] || ""
    reading = Word.normalize_reading(word["reading"])
    image_text = word["image_text"] || raw_text

    notes =
      case verb_group do
        nil -> ""
        g when is_binary(g) and g != "" -> "Group #{g} verb"
        _ -> ""
      end

    notes =
      if notes != "" and image_text != "" and String.ends_with?(image_text, "ます") do
        "#{notes} (from: #{image_text})"
      else
        notes
      end

    # If the AI omitted the text (common for katakana-only words), fall back to reading.
    text = if raw_text in [nil, ""], do: reading, else: raw_text
    reading = if reading in [nil, ""], do: text, else: reading

    # If no separate image form was provided, use the (possibly recovered) text.
    image_text = if image_text in [nil, ""], do: text, else: image_text

    # Clean bracketed expressions like [どうぞ]よろしく[ございます].
    # The bracketed original is preserved in notes.
    {text, image_text, notes} = clean_text_and_notes(text, image_text, notes)

    # Skip entries whose text or reading are not valid Japanese (e.g. Latin
    # words like "CD" that the AI sometimes returns from textbook images).
    if valid_word_text?(text) and valid_kana_only?(reading) do
      %{
        "text" => text,
        "image_text" => image_text,
        "reading" => reading,
        "meaning" => word["meaning"] || "",
        "word_type" => normalize_word_type(word["word_type"]),
        "verb_group" => verb_group,
        "notes" => notes
      }
    end
  end

  defp clean_text_and_notes(text, image_text, notes) do
    text = String.trim(text)

    if String.contains?(text, "[") or String.contains?(text, "]") do
      original = text
      cleaned = String.replace(text, ~r/[\[\]]/u, "")
      new_notes = if notes in [nil, ""], do: original, else: "#{notes} (#{original})"
      {cleaned, cleaned, new_notes}
    else
      {text, image_text, notes}
    end
  end

  # Mirrors Word.valid_japanese_text?/1.
  defp valid_word_text?(text) when is_binary(text) do
    String.to_charlist(text)
    |> Enum.all?(fn cp ->
      (cp >= 0x4E00 and cp <= 0x9FFF) or
        (cp >= 0x3400 and cp <= 0x4DBF) or
        (cp >= 0x3040 and cp <= 0x309F) or
        (cp >= 0x30A0 and cp <= 0x30FF) or
        (cp >= 0x3000 and cp <= 0x303F) or
        cp == 0x30FC
    end)
  end

  defp valid_word_text?(_), do: false

  # Mirrors Word.valid_kana_only?/1 (allows slash for multiple readings).
  defp valid_kana_only?(text) when is_binary(text) do
    String.to_charlist(text)
    |> Enum.all?(fn cp ->
      (cp >= 0x3040 and cp <= 0x309F) or
        (cp >= 0x30A0 and cp <= 0x30FF) or
        cp == 0x30FC or
        cp == 0x002F
    end)
  end

  defp valid_kana_only?(_), do: false

  defp normalize_word_type(nil), do: "other"

  defp normalize_word_type(type) when is_binary(type) do
    normalized = String.downcase(String.trim(type))

    valid_types = [
      "noun",
      "verb",
      "adjective",
      "adverb",
      "particle",
      "pronoun",
      "counter",
      "expression",
      "other"
    ]

    if normalized in valid_types do
      normalized
    else
      "other"
    end
  end

  defp normalize_word_type(_), do: "other"

  defp default_model do
    Application.get_env(:medoru, :openai_vision_model, "gpt-4o")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
