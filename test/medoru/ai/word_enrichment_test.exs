defmodule Medoru.AI.WordEnrichmentTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.WordEnrichment

  setup do
    original_key = Application.get_env(:medoru, :openai_api_key)
    Application.put_env(:medoru, :openai_api_key, "test-key")

    on_exit(fn ->
      Application.put_env(:medoru, :openai_api_key, original_key)
    end)

    :ok
  end

  describe "enrich/2" do
    test "returns enriched word data on successful API response" do
      Req.Test.stub(WordEnrichment, fn conn ->
        assert conn.method == "POST"

        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "meaning" => "Japan",
                  "reading" => "にほん",
                  "difficulty" => 5,
                  "word_type" => "noun",
                  "usage_frequency" => 100,
                  "example_sentence" => "日本に行きたいです。/ 日本は美しい国です。",
                  "example_reading" => "にほんにいきたいです。/ にほんはうつくしいくにです。",
                  "example_meaning" => "I want to go to Japan. / Japan is a beautiful country.",
                  "translations" => %{
                    "bg" => %{
                      "meaning" => "Япония",
                      "example" => "Искам да отида в Япония. / Япония е красива страна."
                    },
                    "ja" => %{
                      "meaning" => "日本",
                      "example" => "日本に行きたいです。/ 日本は美しい国です。"
                    }
                  }
                })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, data} =
               WordEnrichment.enrich("日本",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )

      assert data["meaning"] == "Japan"
      assert data["reading"] == "にほん"
      assert data["difficulty"] == 5
      assert data["word_type"] == "noun"
      assert data["usage_frequency"] == 100

      assert data["example_sentence"] == "日本に行きたいです。/ 日本は美しい国です。"
      assert data["example_reading"] == "にほんにいきたいです。/ にほんはうつくしいくにです。"
      assert data["example_meaning"] == "I want to go to Japan. / Japan is a beautiful country."

      assert data["translations"]["bg"]["meaning"] == "Япония"
      assert data["translations"]["bg"]["example"] == "Искам да отида в Япония. / Япония е красива страна."
      assert data["translations"]["ja"]["meaning"] == "日本"
      assert data["translations"]["ja"]["example"] == "日本に行きたいです。/ 日本は美しい国です。"
    end

    test "normalizes string difficulty to integer" do
      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "meaning" => "book",
                  "reading" => "ほん",
                  "difficulty" => "5",
                  "word_type" => "noun"
                })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, data} =
               WordEnrichment.enrich("本",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )

      assert data["difficulty"] == 5
      assert is_integer(data["difficulty"])
    end

    test "normalizes word_type to lowercase" do
      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "meaning" => "to eat",
                  "reading" => "たべる",
                  "difficulty" => 5,
                  "word_type" => "Verb"
                })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, data} =
               WordEnrichment.enrich("食べる",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )

      assert data["word_type"] == "verb"
    end

    test "returns error when API key is not configured" do
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      assert {:error, "OpenAI API key is not configured" <> _} =
               WordEnrichment.enrich("日本")
    end

    test "returns error on API failure" do
      Req.Test.stub(WordEnrichment, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, "Request failed: " <> _} =
               WordEnrichment.enrich("日本",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "returns error on non-200 status" do
      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{"error" => %{"message" => "Invalid API key"}}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(response))
      end)

      assert {:error, "Invalid API key"} =
               WordEnrichment.enrich("日本",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "returns error on malformed JSON response" do
      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => "not valid json"
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:error, "Failed to parse OpenAI response" <> _} =
               WordEnrichment.enrich("日本",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "uses custom prompt when provided" do
      Req.Test.stub(WordEnrichment, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["messages"]
               |> List.last()
               |> Map.get("content") == "Custom prompt for 日本"

        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(%{
                  "meaning" => "Japan",
                  "reading" => "にほん"
                })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, _} =
               WordEnrichment.enrich("日本",
                 custom_prompt: "Custom prompt for %{word_text}",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end
  end

  describe "generate_pronunciation/2" do
    test "returns audio data on successful TTS response" do
      Req.Test.stub(WordEnrichment, fn conn ->
        assert conn.method == "POST"

        # TTS returns binary MP3 data
        conn
        |> Plug.Conn.put_resp_content_type("audio/mpeg")
        |> Plug.Conn.send_resp(200, <<0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00>>)
      end)

      assert {:ok, audio_data} =
               WordEnrichment.generate_pronunciation("にほん",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )

      assert is_binary(audio_data)
      assert byte_size(audio_data) > 0
    end

    test "returns error when API key is not configured" do
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      assert {:error, "OpenAI API key is not configured" <> _} =
               WordEnrichment.generate_pronunciation("にほん")
    end

    test "returns error on API failure" do
      Req.Test.stub(WordEnrichment, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, "TTS request failed: " <> _} =
               WordEnrichment.generate_pronunciation("にほん",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "returns error on non-200 status" do
      Req.Test.stub(WordEnrichment, fn conn ->
        response = %{"error" => %{"message" => "Invalid voice"}}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(response))
      end)

      assert {:error, "Invalid voice"} =
               WordEnrichment.generate_pronunciation("にほん",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "uses custom text when provided" do
      Req.Test.stub(WordEnrichment, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["input"] == "カスタム"
        assert decoded["voice"] == "shimmer"
        assert decoded["model"] == "gpt-4o-mini-tts"
        assert decoded["speed"] == 0.9

        conn
        |> Plug.Conn.put_resp_content_type("audio/mpeg")
        |> Plug.Conn.send_resp(200, <<0xFF, 0xFB>>)
      end)

      assert {:ok, _} =
               WordEnrichment.generate_pronunciation("にほん",
                 text: "カスタム",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "sends vibe prompt as instructions by default" do
      Req.Test.stub(WordEnrichment, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["instructions"] =~ "late-night jazz radio host"
        assert decoded["instructions"] =~ "velvety"

        conn
        |> Plug.Conn.put_resp_content_type("audio/mpeg")
        |> Plug.Conn.send_resp(200, <<0xFF, 0xFB>>)
      end)

      assert {:ok, _} =
               WordEnrichment.generate_pronunciation("にほん",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end

    test "allows custom instructions" do
      Req.Test.stub(WordEnrichment, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["instructions"] == "Speak like a cheerful anime character"

        conn
        |> Plug.Conn.put_resp_content_type("audio/mpeg")
        |> Plug.Conn.send_resp(200, <<0xFF, 0xFB>>)
      end)

      assert {:ok, _} =
               WordEnrichment.generate_pronunciation("にほん",
                 instructions: "Speak like a cheerful anime character",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end
  end

  describe "generate_image/3" do
    test "returns image data on successful response" do
      Req.Test.stub(WordEnrichment, fn
        %{method: "POST"} = conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)

          assert decoded["model"] == "gpt-image-2"
          assert decoded["size"] == "1024x1024"
          assert decoded["prompt"] =~ "日本"
          assert decoded["prompt"] =~ "Japan"

          response = %{
            "data" => [
              %{"url" => "https://example.com/fake-image.png"}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(response))

        %{method: "GET"} = conn ->
          assert conn.request_path == "/fake-image.png"

          conn
          |> Plug.Conn.put_resp_content_type("image/png")
          |> Plug.Conn.send_resp(200, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)
      end)

      assert {:ok, image_data} =
               WordEnrichment.generate_image("日本", "Japan",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )

      assert is_binary(image_data)
      assert byte_size(image_data) > 0
    end

    test "returns error when API key is not configured" do
      original_key = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original_key)
      end)

      assert {:error, "OpenAI API key is not configured" <> _} =
               WordEnrichment.generate_image("日本", "Japan")
    end

    test "allows custom prompt" do
      Req.Test.stub(WordEnrichment, fn
        %{method: "POST"} = conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)

          assert decoded["prompt"] == "Custom image prompt"

          response = %{
            "data" => [
              %{"url" => "https://example.com/custom.png"}
            ]
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(response))

        %{method: "GET"} = conn ->
          conn
          |> Plug.Conn.put_resp_content_type("image/png")
          |> Plug.Conn.send_resp(200, <<0x89, 0x50, 0x4E, 0x47>>)
      end)

      assert {:ok, _} =
               WordEnrichment.generate_image("日本", "Japan",
                 prompt: "Custom image prompt",
                 req_opts: [plug: {Req.Test, WordEnrichment}]
               )
    end
  end

  describe "predefined_prompt/1" do
    test "interpolates word text into the prompt" do
      prompt = WordEnrichment.predefined_prompt("日本")
      assert prompt =~ "日本"
      assert prompt =~ "meaning"
      assert prompt =~ "reading"
      assert prompt =~ "example_sentence"
      assert prompt =~ " / "
    end
  end

  describe "image_prompt/2" do
    test "interpolates word and meaning into the prompt" do
      prompt = WordEnrichment.image_prompt("日本", "Japan")
      assert prompt =~ "日本"
      assert prompt =~ "Japan"
      assert prompt =~ "anime-style illustration"
      assert prompt =~ "show, don't tell"
    end
  end
end
