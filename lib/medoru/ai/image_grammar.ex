defmodule Medoru.AI.ImageGrammar do
  @moduledoc """
  Extracts grammar sections from an image using OpenAI's Vision API.

  Given an image of a Japanese grammar page (e.g. textbook), this module
  sends the image to gpt-4o and returns a structured object with:
  - Page title
  - Numbered sections (title, description, examples)
  - Grammar pattern detection flags
  """

  @openai_chat_url "https://api.openai.com/v1/chat/completions"

  @extraction_prompt """
Extract all grammar sections from this Japanese textbook page.

Return a JSON object with:
- "title": the page title (e.g. "IV. Grammar Notes"). If no clear title, use "Grammar Lesson".
- "sections": array of numbered sections, each with:
  - "number": section number as integer (1, 2, 3, etc.)
  - "title": section title (e.g. "V て-form", "Verb Groups")
  - "description": the full explanatory text of this section. Preserve all content.
  - "examples": array of examples found in this section (from circled numbers ①②③ etc.), each with:
    - "sentence": Japanese sentence with kanji preserved
    - "reading": full reading in hiragana/katakana (include all furigana)
    - "meaning": English meaning/translation
  - "is_grammar_pattern": true if the title contains grammar pattern markers like V, N, A, Noun, Verb, Adjective, Adverb, or numbered variables like V1, N1, A1, etc. false otherwise.

RULES:
- Numbered sections like "1. Verb Groups", "2. V て-form" are the main sections.
- Sub-sections like "1) Group I Verbs", "(1) When the last sound..." should be included IN the description of their parent section, not as separate sections.
- Circled numbers (①, ②, ③) indicate examples. Extract ALL of them.
- If a section has no circled examples, return an empty examples array.
- Preserve all kanji in sentences.
- Include complete readings with furigana.

Return ONLY a JSON object. No markdown, no explanations.
"""

  @doc """
  Extracts grammar sections from an image binary.

  ## Options

    * `:model` - OpenAI model to use. Defaults to the configured model or "gpt-4o".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, map}` - Map with `"title"` and `"sections"` keys
    * `{:error, String.t()}` - Error message
  """
  def extract_grammar(image_binary, opts \\ []) do
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
        error_message = get_in(response_body, ["error", "message"]) || "OpenAI API returned status #{status}"
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
          {:ok, %{"title" => title, "sections" => sections}} when is_list(sections) ->
            {:ok, %{
              "title" => title || "Grammar Lesson",
              "sections" => Enum.map(sections, &normalize_section/1)
            }}

          {:ok, %{"sections" => sections}} when is_list(sections) ->
            {:ok, %{
              "title" => "Grammar Lesson",
              "sections" => Enum.map(sections, &normalize_section/1)
            }}

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

  defp normalize_section(section) when is_map(section) do
    examples =
      case section["examples"] do
        examples when is_list(examples) -> Enum.map(examples, &normalize_example/1)
        _ -> []
      end

    %{
      "number" => parse_number(section["number"]),
      "title" => section["title"] || "",
      "description" => section["description"] || "",
      "examples" => examples,
      "is_grammar_pattern" => !!section["is_grammar_pattern"]
    }
  end

  defp normalize_section(_), do: nil

  defp normalize_example(example) when is_map(example) do
    %{
      "sentence" => example["sentence"] || "",
      "reading" => example["reading"] || "",
      "meaning" => example["meaning"] || ""
    }
  end

  defp normalize_example(_), do: nil

  defp parse_number(n) when is_integer(n), do: n
  defp parse_number(n) when is_binary(n) do
    case Integer.parse(n) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_number(_), do: 0

  defp default_model do
    Application.get_env(:medoru, :openai_vision_model, "gpt-4o")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
