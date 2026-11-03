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
          examples |> Enum.map(&single_line/1) |> Enum.reject(&(&1 == ""))

        %{"example" => ex} when is_binary(ex) and ex != "" ->
          [single_line(ex)]

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
      [
        step["answer"],
        step["correct_answer"],
        step["sentence"]
      ]
      |> get_first_non_empty()
      |> single_line()

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
        list when is_list(list) ->
          list
          |> Enum.filter(&(is_binary(&1) && String.trim(&1) != ""))
          |> Enum.map(&single_line/1)

        _ ->
          []
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

  defp single_line(text) when is_binary(text) do
    text
    |> String.split(~r/\r\n?|\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp single_line(text), do: text

  @doc """
  Extracts writing fill-in test steps from an image binary.

  Expected response:
  {
    "examples": ["-complete example sentence shown in the image-"],
    "steps": [
      {
        "number": 1,
        "template": "あなたは（___）ですか。",
        "correct_answer": "あなたは（学生）ですか。",
        "alt_correct_answers": ["-alternative full sentence 1-"]
      }
    ]
  }
  """
  def extract_writing_fill_in_steps(image_binary, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    mime_type = Keyword.get(opts, :mime_type, "image/png")
    api_key = get_api_key()

    if api_key == "" do
      {:error, "API key is not configured"}
    else
      prompt = Keyword.get(opts, :prompt, default_writing_fill_in_prompt())
      req_opts = Keyword.get(opts, :req_opts, [])

      case call_vision_api(image_binary, mime_type, prompt,
             api_key: api_key,
             model: model,
             req_opts: req_opts
           ) do
        {:ok, content} -> parse_writing_fill_in_response(content)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_writing_fill_in_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> parse_writing_fill_in_response(decoded)
      {:error, reason} -> {:error, "Failed to parse JSON: #{inspect(reason)}"}
    end
  end

  defp parse_writing_fill_in_response(%{"steps" => steps} = data) when is_list(steps) do
    normalized_steps = Enum.map(steps, &normalize_writing_fill_in_step/1)

    examples =
      case data do
        %{"examples" => examples} when is_list(examples) ->
          examples |> Enum.map(&single_line/1) |> Enum.reject(&(&1 == ""))

        %{"example" => ex} when is_binary(ex) and ex != "" ->
          [single_line(ex)]

        _ ->
          []
      end

    {:ok, %{"examples" => examples, "steps" => normalized_steps}}
  end

  defp parse_writing_fill_in_response(_),
    do: {:error, "Invalid response structure: missing steps"}

  defp normalize_writing_fill_in_step(step) when is_map(step) do
    correct_answer =
      [
        step["correct_answer"],
        step["answer"],
        step["sentence"]
      ]
      |> get_first_non_empty()
      |> single_line()

    template =
      [
        step["template"],
        step["question"]
      ]
      |> get_first_non_empty()
      |> single_line()

    alt_answers =
      case step["alt_correct_answers"] do
        list when is_list(list) ->
          list
          |> Enum.filter(&(is_binary(&1) && String.trim(&1) != ""))
          |> Enum.map(&single_line/1)

        _ ->
          []
      end

    %{
      "number" => parse_number(step["number"]),
      "template" => normalize_template(template),
      "correct_answer" => correct_answer,
      "alt_correct_answers" => alt_answers
    }
  end

  defp normalize_template(template) when is_binary(template) do
    template
    |> String.replace(~r/（\s*）/, "（___）")
    |> String.replace(~r/\(\s*\)/, "(___)")
    |> String.replace(~r/_+/, "___")
  end

  defp normalize_template(template), do: template

  defp default_grammar_make_question_answer_prompt do
    """
    You are an AI assistant helping extract Japanese "make a question and answer it" grammar exercises from an image.

    The page has TWO separate sections. Keep them strictly apart:

    (a) WORKED EXAMPLES section, at the TOP of the page, labeled 例1, 例2, etc.
    Each worked example demonstrates the pattern with its → lines and …… answer lines.
    These worked examples — and ONLY these — go into the top-level `examples` array.

    (b) PRACTICE section, BELOW the worked examples, with NUMBERED practice items
    (1), 2), 3), ...). Each numbered practice item:
    - Describes a situation and topic, e.g. 「家の 部屋で 料理（いいえ）」
    - Ends with a （はい/いいえ） hint indicating whether the answer should be positive or negative.
    These numbered practice items — and ONLY these — become entries in the `steps` array.

    For each numbered requirement, produce:
    - `requirement`: the requirement text exactly as shown (including the （はい/いいえ） hint)
    - `expected_question`: a complete natural Japanese question sentence following the example pattern (e.g. 「家の部屋で料理ができますか。」)
    - `expected_answer`: the complete answer sentence matching the はい/いいえ hint (e.g. 「いいえ、できません。」)
    - `expected_question_reading`: the full reading of `expected_question` in kana only (hiragana/katakana, no kanji, no punctuation)
    - `expected_answer_reading`: the full reading of `expected_answer` in kana only (hiragana/katakana, no kanji, no punctuation)

    Also return ALL worked examples in the top-level `examples` array, one element per example.
    Each example element must preserve the example's FULL multi-line structure exactly as shown in the image, typically three lines in order:
      1. The requirement/prompt line with the （はい/いいえ） hint, e.g. 「この 公園で サッカー（はい）」
      2. The example question sentence, e.g. 「この公園でサッカーができますか。」
      3. The example answer line starting with ……, e.g. 「……はい、できます。」
    Use "\n" between the lines inside each examples element. Do NOT merge lines into one, do NOT drop the hint line, and do NOT drop the …… answer line.

    Return ONLY a valid JSON object in this exact format:

    {
      "examples": ["-worked example from the 例 section: hint line-\n-example question sentence-\n-……example answer line-"],
      "steps": [
        {
          "number": 1,
          "requirement": "-numbered practice item text with （はい/いいえ） hint-",
          "expected_question": "-complete question sentence-",
          "expected_answer": "-complete answer sentence-",
          "expected_question_reading": "-kana only-",
          "expected_answer_reading": "-kana only-"
        }
      ]
    }

    Rules:
    - One object per numbered practice item, in order.
    - NEVER put numbered practice items (1), 2), ...) in the `examples` array. The `examples` array contains only the 例1/例2 worked examples from the top of the page.
    - NEVER put 例 worked examples in the `steps` array. Generate steps only for the numbered practice items.
    - Each `examples` element must contain ALL lines of the example (hint line, question line, and …… answer line), in order, separated by "\n". Never merge them into a single line.
    - `expected_question` and `expected_answer` must be complete sentences ending with 。 (or ？ for the question).
    - The readings must be kana only: no kanji, no punctuation, no spaces.
    - If the image contains no valid exercises, return {"examples": [], "steps": []}.
    """
  end

  @doc """
  Extracts "make a question and answer it" grammar steps from an image binary.

  Expected response:
  {
    "examples": ["この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。"],
    "steps": [
      {
        "number": 1,
        "requirement": "家の 部屋で 料理（いいえ）",
        "expected_question": "家の部屋で料理ができますか。",
        "expected_answer": "いいえ、できません。",
        "expected_question_reading": "いえのへやでりょうりができますか",
        "expected_answer_reading": "いいえできません"
      }
    ]
  }
  """
  def extract_grammar_make_question_answer_steps(image_binary, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    mime_type = Keyword.get(opts, :mime_type, "image/png")
    api_key = get_api_key()

    if api_key == "" do
      {:error, "API key is not configured"}
    else
      prompt = Keyword.get(opts, :prompt, default_grammar_make_question_answer_prompt())
      req_opts = Keyword.get(opts, :req_opts, [])

      case call_vision_api(image_binary, mime_type, prompt,
             api_key: api_key,
             model: model,
             req_opts: req_opts
           ) do
        {:ok, content} -> parse_grammar_make_question_answer_response(content)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_grammar_make_question_answer_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> parse_grammar_make_question_answer_response(decoded)
      {:error, reason} -> {:error, "Failed to parse JSON: #{inspect(reason)}"}
    end
  end

  defp parse_grammar_make_question_answer_response(%{"steps" => steps} = data)
       when is_list(steps) do
    examples = extract_make_question_answer_examples(data)
    normalized_steps = Enum.map(steps, &normalize_make_question_answer_step(&1, examples))
    {:ok, %{"examples" => examples, "steps" => normalized_steps}}
  end

  defp parse_grammar_make_question_answer_response(_),
    do: {:error, "Invalid response structure: missing steps"}

  defp extract_make_question_answer_examples(data) do
    case data do
      %{"examples" => examples} when is_list(examples) ->
        examples |> Enum.map(&multi_line/1) |> Enum.reject(&(&1 == ""))

      %{"example" => ex} when is_binary(ex) and ex != "" ->
        [multi_line(ex)]

      _ ->
        []
    end
  end

  defp normalize_make_question_answer_step(step, examples) when is_map(step) do
    expected_question =
      get_first_non_empty([
        step["expected_question"],
        step["question"],
        step["correct_question"]
      ])
      |> single_line()

    expected_answer =
      get_first_non_empty([
        step["expected_answer"],
        step["answer"],
        step["correct_answer"]
      ])
      |> single_line()

    %{
      "number" => parse_number(step["number"]),
      "requirement" => step["requirement"] |> single_line(),
      "expected_question" => expected_question,
      "expected_answer" => expected_answer,
      "expected_question_reading" =>
        step["expected_question_reading"] |> single_line() |> strip_reading_punctuation(),
      "expected_answer_reading" =>
        step["expected_answer_reading"] |> single_line() |> strip_reading_punctuation(),
      "examples" => examples
    }
  end

  # Normalizes an example string, keeping its internal line structure:
  # trims each line and drops empty lines, but does NOT join lines.
  defp multi_line(text) when is_binary(text) do
    text
    |> String.split(~r/\r\n?|\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp multi_line(text), do: text

  # Readings should be kana-only; strip any stray punctuation/whitespace the
  # model may have included so grading comparisons stay robust.
  defp strip_reading_punctuation(reading) when is_binary(reading) do
    String.replace(reading, ~r/[\s。、！？!?,.・]+/u, "")
  end

  defp strip_reading_punctuation(reading), do: reading

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

  defp default_writing_fill_in_prompt do
    """
    You are an AI assistant helping extract Japanese writing fill-in exercises from an image.

    The image shows an example sentence with a filled blank, followed by numbered questions.
    Each numbered question usually has TWO parts:
    1. A sentence template with one or more blanks (e.g. "あなたは（ ）ですか。").
    2. A short answer/response line directly below it (e.g. "……はい、ミラーです。" or "……いいえ、アメリカ人じゃ ありません。 イギリス人です。").

    Return ONLY a valid JSON object in this exact format:

    {
      "examples": ["-complete example sentence shown in the image-"],
      "steps": [
        {
          "number": 1,
          "template": "-question line plus the answer/response line below it, with ___ for each blank-",
          "correct_answer": "-complete sentence with blanks filled in-",
          "alt_correct_answers": ["-alternative full sentence 1-"]
        }
      ]
    }

    Rules:
    - In `template`, replace every blank with `___` (three underscores).
    - `template` must contain ALL text for the numbered item: the question line with the blank AND the answer/response line below it. Join them into one continuous line separated by a single space. Do NOT drop the second line.
    - `correct_answer` must be the complete sentence with the blank filled in, NOT the response line by itself. For example, if the template is "あなたは（___）ですか。 ……はい、ミラーです。", the correct_answer should be "あなたは（ミラー）ですか。".
    - `correct_answer`, each `example`, and each item in `alt_correct_answers` must also be a single line. Do not split any sentence across multiple lines.
    - If there are alternative valid full sentences (different particles, kanji vs kana, etc.), include them in `alt_correct_answers`.
    - Return ALL example sentences from the image in the `examples` array.
    - If there is no example, return an empty array for `examples`.
    - If the image contains no valid writing fill-in exercises, return {"examples": [], "steps": []}.
    """
  end

  defp get_api_key do
    Application.get_env(:medoru, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY") ||
      ""
  end
end
