defmodule Medoru.AI.KanjiEnrichment do
  @moduledoc """
  Enriches kanji data by calling the OpenAI API.

  Provides three enrichment paths:
  - `enrich/2` - main kanji fields (meanings, radicals, frequency, JLPT/school level, translations)
  - `enrich_readings/2` - on/kun readings
  - `enrich_stroke_data/2` - stroke data, preferring the local KanjiVG dataset and falling back to AI
  """

  alias Medoru.Content.KanjiStrokeData

  @openai_chat_url "https://api.openai.com/v1/chat/completions"

  @main_prompt """
  You are a Japanese language expert. Given the kanji character below, provide comprehensive linguistic data in JSON format.

  Character: %{character}

  Return a JSON object with exactly these fields:
  - "meanings": English meaning(s) separated by ", "
  - "stroke_count": stroke count as an integer
  - "jlpt_level": JLPT level as integer 1-5 (5 = N5 beginner, 1 = N1 expert). Estimate if unsure.
  - "school_level": Japanese school grade level as integer 1-7 (1-6 elementary, 7 junior high). Estimate if unsure.
  - "frequency": Estimated frequency rank (1 = most common, higher = less common). Default around 2500 if unknown.
  - "radicals": The kanji's radical character(s) as a single string, e.g. "水" or "水 氵". Use the classical radical.
  - "translations": An object with:
    - "bg": {"meanings": Bulgarian meaning(s) separated by ", "}
    - "ja": {"meanings": Japanese explanation of the meaning in Japanese, separated by ", "}

  Important:
  - Return ONLY valid JSON, no markdown, no explanations.
  - Use ", " to separate multiple meanings.
  """

  @readings_prompt """
  You are a Japanese language expert. Given the kanji character below, provide its on'yomi and kun'yomi readings in JSON format.

  Character: %{character}

  Return a JSON object with exactly this field:
  - "readings": an array of objects, each with:
    - "reading_type": either "on" or "kun"
    - "reading": the reading in kana (katakana for on, hiragana for kun)
    - "romaji": Hepburn romaji
    - "usage_notes": optional short note such as "formal" or "when used in compounds"

  Important:
  - Return ONLY valid JSON, no markdown, no explanations.
  - Include common readings only; 1-3 on and 1-3 kun readings is usually enough.
  """

  @stroke_data_prompt """
  You are an expert in Japanese kanji stroke order and SVG paths.

  Given the kanji character below, return stroke data in the exact format used by the KanjiVG dataset (109x109 coordinate system).

  Character: %{character}

  Return a JSON object with exactly this field:
  - "stroke_data": an object with:
    - "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"}
    - "strokes": an array of objects, each with:
      - "path": an SVG path string for one stroke (e.g. "M11,54.25 c3.19,0.62 ...")
      - "order": 1-based stroke order integer
      - "type": one of "curve", "straight", "closed", "unknown"
      - "direction": one of "left-to-right", "right-to-left", "top-to-bottom", "bottom-to-top", "unknown"

  Important:
  - Return ONLY valid JSON, no markdown, no explanations.
  - If you cannot provide accurate stroke paths, omit the "stroke_data" field entirely.
  """

  @doc """
  Enriches the main non-reading, non-stroke kanji fields.

  ## Options

    * `:custom_prompt` - Overrides the predefined prompt. The character will still
      be interpolated via `%{character}`.
    * `:model` - OpenAI model to use. Defaults to the configured model or "gpt-4o-mini".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, map}` - Enriched kanji data with string keys
    * `{:error, String.t()}` - Error message
  """
  def enrich(character, opts \\ []) do
    custom_prompt = Keyword.get(opts, :custom_prompt)
    model = Keyword.get(opts, :model, default_model())
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      prompt = build_prompt(@main_prompt, character, custom_prompt)

      case call_openai(prompt, model, api_key, req_opts) do
        {:ok, data} -> {:ok, normalize_main_fields(data)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the predefined main prompt template for a given character.
  """
  def main_prompt(character) do
    String.replace(@main_prompt, "%{character}", character)
  end

  @doc """
  Enriches on/kun readings for a kanji.

  ## Options

    * `:custom_prompt` - Overrides the predefined prompt.
    * `:model` - OpenAI model to use.
    * `:req_opts` - Extra options passed to `Req.post`.

  ## Returns

    * `{:ok, %{"readings" => [...]}}`
    * `{:error, String.t()}`
  """
  def enrich_readings(character, opts \\ []) do
    custom_prompt = Keyword.get(opts, :custom_prompt)
    model = Keyword.get(opts, :model, default_model())
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      prompt = build_prompt(@readings_prompt, character, custom_prompt)

      case call_openai(prompt, model, api_key, req_opts) do
        {:ok, data} -> {:ok, normalize_readings_response(data)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the predefined readings prompt template for a given character.
  """
  def readings_prompt(character) do
    String.replace(@readings_prompt, "%{character}", character)
  end

  @doc """
  Returns stroke data for a kanji, preferring the local KanjiVG dataset.

  If the local SVG file is found, its parsed stroke data is returned immediately.
  Otherwise the AI is asked to generate stroke data.

  ## Options

    * `:custom_prompt` - Overrides the predefined AI fallback prompt.
    * `:model` - OpenAI model to use.
    * `:req_opts` - Extra options passed to `Req.post`.

  ## Returns

    * `{:ok, %{"stroke_data" => map}}`
    * `{:error, String.t()}`
  """
  def enrich_stroke_data(character, opts \\ []) do
    case KanjiStrokeData.find(character) do
      nil ->
        enrich_stroke_data_from_ai(character, opts)

      stroke_data ->
        {:ok, %{"stroke_data" => stroke_data, "source" => "kanjivg"}}
    end
  end

  defp enrich_stroke_data_from_ai(character, opts) do
    custom_prompt = Keyword.get(opts, :custom_prompt)
    model = Keyword.get(opts, :model, default_model())
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      prompt = build_prompt(@stroke_data_prompt, character, custom_prompt)

      case call_openai(prompt, model, api_key, req_opts) do
        {:ok, data} -> {:ok, normalize_stroke_data_response(data)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the predefined stroke-data prompt template for a given character.
  """
  def stroke_data_prompt(character) do
    String.replace(@stroke_data_prompt, "%{character}", character)
  end

  defp build_prompt(default, character, nil) do
    String.replace(default, "%{character}", character)
  end

  defp build_prompt(_default, character, custom_prompt) do
    String.replace(custom_prompt, "%{character}", character)
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
      temperature: 0.3
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
        {:ok, data}

      {:ok, _} ->
        {:error, "OpenAI returned non-object JSON"}

      {:error, decode_error} ->
        {:error, "Failed to parse OpenAI response: #{Exception.message(decode_error)}"}
    end
  end

  defp parse_response(_) do
    {:error, "Unexpected response format from OpenAI API"}
  end

  defp normalize_main_fields(data) do
    data
    |> maybe_normalize_integer("stroke_count")
    |> maybe_normalize_integer("jlpt_level")
    |> maybe_normalize_integer("school_level")
    |> maybe_normalize_integer("frequency")
    |> normalize_radicals_field("radicals")
    |> normalize_translation_meanings("bg")
    |> normalize_translation_meanings("ja")
  end

  defp normalize_readings_response(data) do
    readings =
      case data["readings"] do
        list when is_list(list) -> Enum.map(list, &normalize_reading/1)
        _ -> []
      end

    Map.put(data, "readings", readings)
  end

  defp normalize_reading(reading) when is_map(reading) do
    type =
      case reading["reading_type"] do
        val when is_binary(val) ->
          normalized = String.downcase(String.trim(val))
          if normalized in ["on", "kun"], do: normalized, else: "on"

        _ ->
          "on"
      end

    %{
      "reading_type" => type,
      "reading" => to_string(reading["reading"] || ""),
      "romaji" => to_string(reading["romaji"] || ""),
      "usage_notes" => to_string(reading["usage_notes"] || "")
    }
  end

  defp normalize_reading(_),
    do: %{"reading_type" => "on", "reading" => "", "romaji" => "", "usage_notes" => ""}

  defp normalize_stroke_data_response(data) do
    case data["stroke_data"] do
      stroke_data when is_map(stroke_data) ->
        strokes =
          case stroke_data["strokes"] do
            list when is_list(list) -> Enum.map(list, &normalize_stroke/1)
            _ -> []
          end

        bounds =
          stroke_data["bounds"] ||
            %{
              "width" => 109,
              "height" => 109,
              "viewBox" => "0 0 109 109"
            }

        %{"stroke_data" => %{"bounds" => bounds, "strokes" => strokes}, "source" => "ai"}

      _ ->
        %{"stroke_data" => nil, "source" => "ai"}
    end
  end

  defp normalize_stroke(stroke) when is_map(stroke) do
    %{
      "path" => to_string(stroke["path"] || ""),
      "order" => normalize_integer(stroke["order"]),
      "type" => to_string(stroke["type"] || "unknown"),
      "direction" => to_string(stroke["direction"] || "unknown")
    }
  end

  defp normalize_stroke(_),
    do: %{"path" => "", "order" => 0, "type" => "unknown", "direction" => "unknown"}

  defp maybe_normalize_integer(data, field) do
    case data[field] do
      val when is_binary(val) ->
        case Integer.parse(val) do
          {int, _} -> Map.put(data, field, int)
          :error -> data
        end

      val when is_integer(val) ->
        data

      _ ->
        data
    end
  end

  defp normalize_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp normalize_integer(val) when is_integer(val), do: val
  defp normalize_integer(_), do: 0

  defp normalize_radicals_field(data, field) do
    case data[field] do
      val when is_binary(val) ->
        radicals =
          val
          |> String.replace(",", " ")
          |> String.split()
          |> Enum.reject(&(&1 == ""))

        Map.put(data, field, radicals)

      val when is_list(val) ->
        Map.put(data, field, Enum.map(val, &to_string/1))

      _ ->
        data
    end
  end

  defp normalize_translation_meanings(data, locale) do
    case get_in(data, ["translations", locale, "meanings"]) do
      meanings when is_binary(meanings) ->
        parsed =
          meanings
          |> String.split(~r/[，,、]/u)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        put_in(data, ["translations", locale, "meanings"], parsed)

      meanings when is_list(meanings) ->
        put_in(data, ["translations", locale, "meanings"], Enum.map(meanings, &to_string/1))

      _ ->
        data
    end
  end

  defp default_model do
    Application.get_env(:medoru, :openai_model, "gpt-4o-mini")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
