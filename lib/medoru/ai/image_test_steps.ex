defmodule Medoru.AI.ImageTestSteps do
  @moduledoc """
  Extracts grammar pattern test step data from uploaded images using OpenAI's Vision API.
  """

  require Logger

  @default_model "gpt-4o-mini"

  @doc """
  Extracts grammar pattern test steps from an image binary.

  Expected response:
  {
    "examples": ["-complete example sentence 1-", "-complete example sentence 2-"],
    "steps": [
      {
        "number": 1,
        "words": "word1 / word2 / word3",
        "correct_answer": "-complete answer sentence-",
        "alt_correct_answers": ["-alternative 1-", "-alternative 2-"]
      }
    ]
  }
  """
  def extract_grammar_pattern_steps(image_binary, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    mime_type = Keyword.get(opts, :mime_type, "image/png")
    api_key = get_api_key()

    if api_key == "" do
      {:error, "API key is not configured"}
    else
      prompt = Keyword.get(opts, :prompt, default_grammar_pattern_prompt())
      req_opts = Keyword.get(opts, :req_opts, [])

      case call_vision_api(image_binary, mime_type, prompt,
             api_key: api_key,
             model: model,
             req_opts: req_opts
           ) do
        {:ok, content} -> parse_response(content)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def call_vision_api(image_binary, mime_type, prompt, opts \\ []) do
    api_key = Keyword.get(opts, :api_key, get_api_key())
    model = Keyword.get(opts, :model, @default_model)
    req_opts = Keyword.get(opts, :req_opts, [])

    base_url = System.get_env("OPENAI_API_BASE", "https://api.openai.com/v1")

    body = %{
      model: model,
      messages: [
        %{
          role: "user",
          content: [
            %{type: "text", text: prompt},
            %{
              type: "image_url",
              image_url: %{
                url: "data:#{mime_type};base64,#{Base.encode64(image_binary)}"
              }
            }
          ]
        }
      ],
      response_format: %{type: "json_object"},
      max_tokens: 2500
    }

    req =
      Req.new(
        url: "#{base_url}/chat/completions",
        headers: [{"Authorization", "Bearer #{api_key}"}, {"Content-Type", "application/json"}],
        json: body
      )
      |> Req.merge(req_opts)

    case Req.post(req) do
      {:ok, %{status: 200, body: response_body}} ->
        extract_content(response_body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenAI Vision API error: status=#{status}, body=#{inspect(body)}")
        {:error, "API request failed with status #{status}"}

      {:error, reason} ->
        Logger.error("OpenAI Vision API request failed: #{inspect(reason)}")
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract_content(%{"choices" => [%{"message" => %{"refusal" => refusal}} | _]})
       when is_binary(refusal) and refusal != "" do
    {:error, "OpenAI refused: #{refusal}"}
  end

  defp extract_content(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    {:ok, strip_markdown_code_blocks(content)}
  end

  defp extract_content(_), do: {:error, "Unexpected API response format"}

  defp strip_markdown_code_blocks(content) do
    content
    |> String.replace(~r/^```(?:json)?\s*/, "")
    |> String.replace(~r/\s*```$/, "")
    |> String.trim()
  end

  defp parse_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> parse_response(decoded)
      {:error, reason} -> {:error, "Failed to parse JSON: #{inspect(reason)}"}
    end
  end

  defp parse_response(%{"steps" => steps} = data) when is_list(steps) do
    normalized_steps = Enum.map(steps, &normalize_step/1)

    examples =
      case data do
        %{"examples" => examples} when is_list(examples) ->
          examples |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

        %{"example" => ex} when is_binary(ex) and ex != "" ->
          [String.trim(ex)]

        _ ->
          []
      end

    {:ok,
     %{
       "examples" => examples,
       "example" => List.first(examples, ""),
       "steps" => normalized_steps
     }}
  end

  defp parse_response(_), do: {:error, "Invalid response structure: missing steps"}

  defp normalize_step(step) when is_map(step) do
    correct_answer =
      get_first_non_empty([
        step["answer"],
        step["correct_answer"],
        step["sentence"]
      ])

    words =
      get_first_non_empty([
        step["words"],
        step["word_bank"],
        step["word_choices"],
        step["choices"]
      ])
      |> normalize_words_separator()

    alt_answers =
      case step["alt_correct_answers"] do
        list when is_list(list) -> Enum.filter(list, &(is_binary(&1) && String.trim(&1) != ""))
        _ -> []
      end

    %{
      "number" => parse_number(step["number"]),
      "words" => words,
      "correct_answer" => correct_answer,
      "alt_correct_answers" => alt_answers
    }
  end

  defp parse_number(nil), do: nil
  defp parse_number(n) when is_integer(n), do: n
  defp parse_number(n) when is_binary(n), do: String.to_integer(n)

  defp get_first_non_empty(values) do
    Enum.find(values, "", fn v -> is_binary(v) && String.trim(v) != "" end)
  end

  defp normalize_words_separator(""), do: ""

  defp normalize_words_separator(words) when is_binary(words) do
    words
    |> String.replace("・", " / ")
    |> String.replace(",", " / ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp default_grammar_pattern_prompt do
    """
    You are an AI assistant helping extract Japanese grammar pattern exercises from an image.

    The image may contain an example sentence plus one or more numbered questions. Each question has:
    - A set of words to rearrange
    - A correct answer sentence

    Return ONLY a valid JSON object in this exact format:

    {
      "examples": ["-complete example sentence shown in the image-"],
      "steps": [
        {
          "number": 1,
          "words": "word1 / word2 / word3 / ...",
          "correct_answer": "-complete correct sentence-",
          "alt_correct_answers": ["-alternative correct sentence 1-", "-alternative correct sentence 2-"]
        }
      ]
    }

    Rules:
    - In `words`, separate each word with ` / ` exactly (e.g. "私 / は / 学生 / です").
    - If the image uses `・` between words, convert it to ` / `.
    - `correct_answer` must be a complete sentence, not just the missing part.
    - For each numbered question, generate the answer sentence by applying the example's grammar pattern to the given words.
    - If there are alternative valid answers (different particles, kanji vs kana, etc.), include them in `alt_correct_answers`.
    - Return ALL example sentences from the image in the `examples` array.
    - If there is no example, return an empty array for `examples`.
    - If the image contains no valid grammar pattern exercises, return {"examples": [], "steps": []}.
    """
  end

  defp get_api_key do
    Application.get_env(:medoru, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY") ||
      ""
  end
end
