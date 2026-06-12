defmodule Medoru.AI.WordEnrichment do
  @moduledoc """
  Enriches word data and generates pronunciation audio by calling the OpenAI API.

  The enrichment predefined prompt asks for all word fields including meanings,
  readings, examples, and translations. Meanings and examples are returned with
  multiple values separated by " / ".

  The TTS function generates MP3 pronunciation audio using OpenAI's speech API.
  """

  @openai_chat_url "https://api.openai.com/v1/chat/completions"
  @openai_tts_url "https://api.openai.com/v1/audio/speech"
  @openai_image_url "https://api.openai.com/v1/images/generations"

  @tts_vibe_prompt """
  Voice: The voice should be deep, velvety, and effortlessly cool, like a late-night jazz radio host.

  Tone: The tone is smooth, laid-back, and inviting, creating a relaxed and easygoing atmosphere.

  Personality: The delivery exudes confidence, charm, and a touch of playful sophistication, as if guiding the listener through a luxurious experience.

  Pronunciation: Words should be drawn out slightly with a rhythmic, melodic quality, emphasizing key phrases with a silky flow.

  Phrasing: Sentences should be fluid, conversational, and slightly poetic, with pauses that let the listener soak in the cool, jazzy vibe.
  """

  @image_prompt """
  Always generate a square image (1:1 aspect ratio).

  Do not include any text, letters, kanji, kana, numbers, punctuation, symbols, arrows, signs, UI elements, captions, labels, speech bubbles, question marks, thought bubbles, logos, watermarks, or written language of any kind anywhere in the image.

  The meaning must be communicated visually only ("show, don't tell").

  Create a single clear visual scene that represents the meaning of the target Japanese word. The viewer should be able to infer the meaning from the image without reading anything.

  Use clear visual storytelling through:

  * people
  * objects
  * actions
  * facial expressions
  * body language
  * environment
  * atmosphere
  * context

  Prefer literal visual interpretations when possible.

  For abstract concepts, expressions, adverbs, particles, emotions, reactions, or conversational phrases, represent the meaning through a realistic situation, interaction, emotion, or metaphorical visual context rather than written symbols or explanatory elements.

  When the target word is a concrete noun, the noun should be the primary focus of the image. Human characters are optional and should only be included if they help communicate the meaning more clearly.

  When the target word is an action or verb, clearly show the action being performed.

  When the target word describes a feeling, state, relationship, direction, quantity, or abstract concept, create a simple scene that naturally conveys that meaning through context and body language.

  Keep the composition simple, focused, and easy to understand at a glance.

  Avoid:

  * unnecessary background clutter
  * multiple competing actions
  * ambiguous symbolism
  * surreal elements that obscure meaning
  * educational diagrams
  * visual puzzles

  Style:

  * clean anime-style illustration
  * polished and professional
  * expressive characters
  * soft natural lighting
  * visually clear
  * aesthetically pleasing
  * suitable for a Japanese vocabulary learning application

  Target Japanese word: %{word}

  Meaning to represent: %{meaning}

  Generate a single image whose primary purpose is to teach the meaning of this word visually.
  """

  @predefined_prompt """
  You are a Japanese language expert. Given the Japanese word below, provide comprehensive linguistic data in JSON format.

  Word: %{word_text}

  Return a JSON object with exactly these fields:
  - "meaning": English meaning (concise, 1-3 synonyms if applicable), separated by " / "
  - "reading": Hiragana or katakana reading of the word
  - "difficulty": JLPT level as integer 1-5 (5 = N5 beginner, 1 = N1 expert). Estimate if unsure.
  - "word_type": One of: noun, verb, adjective, adverb, particle, pronoun, counter, expression, other
  - "usage_frequency": Estimated frequency rank (1 = most common, higher = less common). Default around 1000 if unknown.
  - "example_sentence": One or more example sentences in Japanese, separated by " / "
  - "example_reading": The readings of the example sentences in hiragana/katakana, separated by " / "
  - "example_meaning": English translations of the example sentences, separated by " / "
  - "translations": An object with:
    - "bg": {"meaning": Bulgarian meaning(s) separated by " / ", "example": Bulgarian example sentence(s) separated by " / "}
    - "ja": {"meaning": Japanese explanation of the meaning in Japanese, separated by " / ", "example": Japanese example sentence(s) separated by " / "}

  Important:
  - Return ONLY valid JSON, no markdown, no explanations.
  - If providing multiple meanings or examples, always separate them with " / " (space-slash-space).
  - Ensure example_sentence, example_reading, and example_meaning have the same number of parts.
  - Ensure translations.bg.meaning, translations.bg.example, translations.ja.meaning, and translations.ja.example also use " / " for multiple values.
  """

  @doc """
  Enriches a word by calling the OpenAI API.

  ## Options

    * `:custom_prompt` - Overrides the predefined prompt. The word text will still
      be interpolated via `%{word_text}`.
    * `:model` - OpenAI model to use. Defaults to the configured model or "gpt-4o-mini".

  ## Returns

    * `{:ok, map}` - Enriched word data with string keys
    * `{:error, String.t()}` - Error message
  """
  def enrich(word_text, opts \\ []) do
    custom_prompt = Keyword.get(opts, :custom_prompt)
    model = Keyword.get(opts, :model, default_model())
    api_key = api_key()
    req_opts = Keyword.get(opts, :req_opts, [])

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      prompt = build_prompt(word_text, custom_prompt)
      call_openai(prompt, model, api_key, req_opts)
    end
  end

  @doc """
  Returns the predefined prompt template for a given word text.
  """
  def predefined_prompt(word_text) do
    String.replace(@predefined_prompt, "%{word_text}", word_text)
  end

  defp build_prompt(word_text, nil) do
    predefined_prompt(word_text)
  end

  defp build_prompt(word_text, custom_prompt) do
    String.replace(custom_prompt, "%{word_text}", word_text)
  end

  @doc """
  Returns the default TTS vibe prompt.
  """
  def tts_vibe_prompt do
    @tts_vibe_prompt
  end

  @doc """
  Returns the default image generation prompt for a given word and meaning.
  """
  def image_prompt(word, meaning) do
    @image_prompt
    |> String.replace("%{word}", word)
    |> String.replace("%{meaning}", meaning)
  end

  @doc """
  Generates pronunciation audio for a word using OpenAI's TTS API.

  ## Options

    * `:text` - The text to speak. Defaults to the word_text.
    * `:voice` - OpenAI voice to use. Defaults to the configured voice or "nova".
    * `:speed` - Speech speed (0.25 to 4.0). Defaults to the configured speed or 0.9.
    * `:model` - TTS model to use. Defaults to the configured TTS model or "tts-1-hd".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, binary}` - MP3 audio data
    * `{:error, String.t()}` - Error message
  """
  def generate_pronunciation(word_text, opts \\ []) do
    text = Keyword.get(opts, :text, word_text)
    voice = Keyword.get(opts, :voice, default_tts_voice())
    speed = Keyword.get(opts, :speed, default_tts_speed())
    model = Keyword.get(opts, :model, default_tts_model())
    instructions = Keyword.get(opts, :instructions, @tts_vibe_prompt)
    req_opts = Keyword.get(opts, :req_opts, [])
    api_key = api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      call_tts(text, model, voice, speed, instructions, api_key, req_opts)
    end
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
        {:ok, normalize_fields(data)}

      {:ok, _} ->
        {:error, "OpenAI returned non-object JSON"}

      {:error, decode_error} ->
        {:error, "Failed to parse OpenAI response: #{Exception.message(decode_error)}"}
    end
  end

  defp parse_response(_) do
    {:error, "Unexpected response format from OpenAI API"}
  end

  # Normalize field names and types to match the Word schema expectations
  defp normalize_fields(data) do
    data
    |> maybe_normalize_integer("difficulty")
    |> maybe_normalize_integer("usage_frequency")
    |> maybe_normalize_integer("sort_score")
    |> maybe_normalize_integer("core_rank")
    |> maybe_normalize_word_type("word_type")
  end

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

  defp maybe_normalize_word_type(data, "word_type") do
    case data["word_type"] do
      val when is_binary(val) ->
        normalized = String.downcase(String.trim(val))

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
          Map.put(data, "word_type", normalized)
        else
          data
        end

      _ ->
        data
    end
  end

  defp call_tts(text, model, voice, speed, instructions, api_key, req_opts) do
    body = %{
      model: model,
      input: text,
      voice: voice,
      response_format: "mp3",
      speed: speed,
      instructions: instructions
    }

    opts =
      [
        headers: [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}],
        json: body,
        receive_timeout: 60_000
      ] ++ req_opts

    case Req.post(@openai_tts_url, opts) do
      {:ok, %{status: 200, body: audio_data}} when is_binary(audio_data) ->
        {:ok, audio_data}

      {:ok, %{status: 200, body: body}} ->
        # Req might wrap the body in an io_list or other format
        {:ok, IO.iodata_to_binary(body)}

      {:ok, %{status: status, body: response_body}} when is_map(response_body) ->
        error_message =
          get_in(response_body, ["error", "message"]) ||
            "OpenAI TTS API returned status #{status}"

        {:error, error_message}

      {:ok, %{status: status}} ->
        {:error, "OpenAI TTS API returned status #{status}"}

      {:error, exception} ->
        {:error, "TTS request failed: #{Exception.message(exception)}"}
    end
  end

  defp default_model do
    Application.get_env(:medoru, :openai_model, "gpt-4o-mini")
  end

  defp default_tts_model do
    Application.get_env(:medoru, :openai_tts_model, "gpt-4o-mini-tts")
  end

  defp default_tts_voice do
    Application.get_env(:medoru, :openai_tts_voice, "shimmer")
  end

  defp default_tts_speed do
    Application.get_env(:medoru, :openai_tts_speed, 0.9)
  end

  @doc """
  Generates an illustration image for a word using OpenAI's image generation API.

  ## Options

    * `:prompt` - Overrides the predefined image prompt.
    * `:model` - Image model to use. Defaults to the configured model or "dall-e-3".
    * `:req_opts` - Extra options passed to `Req.post` (useful for testing).

  ## Returns

    * `{:ok, binary}` - PNG image data
    * `{:error, String.t()}` - Error message
  """
  def generate_image(word_text, meaning, opts \\ []) do
    custom_prompt = Keyword.get(opts, :prompt)
    model = Keyword.get(opts, :model, default_image_model())
    req_opts = Keyword.get(opts, :req_opts, [])
    api_key = api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, "OpenAI API key is not configured. Set OPENAI_API_KEY environment variable."}
    else
      prompt = if custom_prompt, do: custom_prompt, else: image_prompt(word_text, meaning)
      call_image_generation(prompt, model, api_key, req_opts)
    end
  end

  defp call_image_generation(prompt, model, api_key, req_opts) do
    body = %{
      model: model,
      prompt: prompt,
      n: 1,
      size: "1024x1024",
      quality: "medium"
    }

    opts =
      [
        headers: [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}],
        json: body,
        receive_timeout: 180_000
      ] ++ req_opts

    case Req.post(@openai_image_url, opts) do
      {:ok, %{status: 200, body: response_body}} ->
        response_body = decode_json_body(response_body)

        data_item = get_in(response_body, ["data", Access.at(0)]) || %{}

        cond do
          image_url = data_item["url"] ->
            download_image(image_url, req_opts)

          b64_data = data_item["b64_json"] ->
            {:ok, Base.decode64!(b64_data)}

          true ->
            error_detail = get_in(response_body, ["error", "message"]) || inspect(response_body)
            {:error, "No image data in OpenAI response: #{error_detail}"}
        end

      {:ok, %{status: status, body: response_body}} ->
        response_body = decode_json_body(response_body)

        error_message =
          get_in(response_body, ["error", "message"]) ||
            "OpenAI Image API returned status #{status}"

        {:error, error_message}

      {:error, exception} ->
        {:error, "Image generation request failed: #{Exception.message(exception)}"}
    end
  end

  defp decode_json_body(%{} = body), do: body

  defp decode_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"raw" => body}
    end
  end

  defp decode_json_body(body), do: %{"raw" => inspect(body)}

  defp download_image(url, req_opts) do
    opts = [receive_timeout: 60_000] ++ req_opts

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: image_data}} when is_binary(image_data) ->
        {:ok, image_data}

      {:ok, %{status: 200, body: body}} ->
        {:ok, IO.iodata_to_binary(body)}

      {:ok, %{status: status}} ->
        {:error, "Image download failed with status #{status}"}

      {:error, exception} ->
        {:error, "Image download failed: #{Exception.message(exception)}"}
    end
  end

  defp default_image_model do
    Application.get_env(:medoru, :openai_image_model, "gpt-image-2")
  end

  defp api_key do
    Application.get_env(:medoru, :openai_api_key)
  end
end
