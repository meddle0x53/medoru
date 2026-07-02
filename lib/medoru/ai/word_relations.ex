defmodule Medoru.AI.WordRelations do
  @moduledoc """
  Generates word relation suggestions (synonyms, antonyms, and common
  expressions) for a Japanese word using the OpenAI API.

  Suggested items are matched against the local database by the caller. Items
  that do not match an existing word are kept as text-only suggestions.
  """

  @openai_chat_url "https://api.openai.com/v1/chat/completions"

  @relation_types [:noun, :verb, :adjective, :adverb]

  @predefined_prompt """
  You are a Japanese language expert. Given the Japanese word below, return a
  JSON object with synonyms, antonyms, and common expressions that use this
  word.

  Word: %{word_text}
  Reading: %{reading}
  Meaning: %{meaning}
  Part of speech: %{word_type}

  Return a JSON object with exactly these fields:
  - "synonyms": an array of up to 5 Japanese synonyms. Each item is an object with:
      - "text": the Japanese word (kanji/kana)
      - "reading": hiragana or katakana reading
      - "meaning": short English meaning
  - "antonyms": an array of up to 5 Japanese antonyms. Each item uses the same object shape as synonyms.
  - "expressions": an array of 5-10 common Japanese expressions, set phrases, or collocations that contain this word. Each item is an object with:
      - "text": the Japanese expression
      - "reading": hiragana or katakana reading
      - "meaning": short English meaning

  Important:
  - Return ONLY valid JSON, no markdown, no explanations.
  - Use the exact Japanese word shape for "text" values (kanji if standard).
  - Do not include the source word itself in the synonyms or antonyms arrays.
  """

  @doc """
  Generates relation suggestions for a word.

  ## Returns

    * `{:ok, %{synonyms: [...], antonyms: [...], expressions: [...]}}` where each
      item is a map with string keys `"text"`, `"reading"`, `"meaning"`
    * `{:error, String.t()}` - Error message
  """
  def generate(word_text, reading, meaning, word_type, opts \\ []) do
    model = Keyword.get(opts, :model, default_model())
    custom_prompt = Keyword.get(opts, :custom_prompt)
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if word_type not in @relation_types do
      {:error, "Word relations are only supported for nouns, verbs, adjectives, and adverbs."}
    else
      if is_nil(api_key) or api_key == "" do
        {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
      else
        prompt = build_prompt(word_text, reading, meaning, word_type, custom_prompt)
        call_openai(prompt, model, api_key, req_opts)
      end
    end
  end

  @doc """
  Returns the predefined prompt template for a word.
  """
  def predefined_prompt(word_text, reading, meaning, word_type) do
    @predefined_prompt
    |> String.replace("%{word_text}", word_text || "")
    |> String.replace("%{reading}", reading || "")
    |> String.replace("%{meaning}", meaning || "")
    |> String.replace("%{word_type}", to_string(word_type))
  end

  defp build_prompt(word_text, reading, meaning, word_type, nil) do
    predefined_prompt(word_text, reading, meaning, word_type)
  end

  defp build_prompt(word_text, _reading, _meaning, _word_type, custom_prompt) do
    String.replace(custom_prompt, "%{word_text}", word_text || "")
  end

  defp call_openai(prompt, model, api_key, req_opts) do
    body = %{
      model: model,
      messages: [
        %{
          role: "system",
          content: "You are a helpful Japanese language assistant that returns only valid JSON."
        },
        %{role: "user", content: prompt}
      ],
      response_format: %{type: "json_object"},
      temperature: 0.4
    }

    opts =
      [
        headers: [{"authorization", "Bearer #{api_key}"}],
        json: body,
        receive_timeout: 30_000
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

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    case Jason.decode(content) do
      {:ok, data} when is_map(data) ->
        {:ok, normalize_response(data)}

      {:ok, _} ->
        {:error, "OpenAI returned non-object JSON"}

      {:error, decode_error} ->
        {:error, "Failed to parse OpenAI response: #{Exception.message(decode_error)}"}
    end
  end

  defp parse_response(_) do
    {:error, "Unexpected response format from OpenAI API"}
  end

  defp normalize_response(data) do
    %{
      "synonyms" => normalize_items(data["synonyms"]),
      "antonyms" => normalize_items(data["antonyms"]),
      "expressions" => normalize_items(data["expressions"])
    }
  end

  defp normalize_items(nil), do: []

  defp normalize_items(items) when is_list(items) do
    items
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn item ->
      %{
        "text" => to_string(item["text"] || "") |> String.trim(),
        "reading" => to_string(item["reading"] || "") |> String.trim(),
        "meaning" => to_string(item["meaning"] || "") |> String.trim()
      }
    end)
    |> Enum.reject(fn item -> item["text"] == "" end)
  end

  defp default_model do
    Application.get_env(:medoru, :openai_model, "gpt-4o-mini")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
