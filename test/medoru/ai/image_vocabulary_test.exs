defmodule Medoru.AI.ImageVocabularyTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.ImageVocabulary

  @dummy_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
               0x44, 0x52>>

  describe "extract_vocabulary/2" do
    test "returns error when API key is not configured" do
      without_api_key(fn ->
        assert {:error, message} = ImageVocabulary.extract_vocabulary(@dummy_png)
        assert message =~ "API key is not configured"
      end)
    end

    test "handles successful API response with words array" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "消す",
                        "reading" => "けす",
                        "meaning" => "to turn off",
                        "word_type" => "verb",
                        "verb_group" => "I",
                        "image_text" => "消します"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["text"] == "消す"
        assert word["reading"] == "けす"
        assert word["meaning"] == "to turn off"
        assert word["word_type"] == "verb"
        assert word["verb_group"] == "I"
        assert word["image_text"] == "消します"
        assert word["notes"] == "Group I verb (from: 消します)"
      end)
    end

    test "handles successful API response with words object wrapper" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "words" => [
                        %{
                          "text" => "電気",
                          "reading" => "でんき",
                          "meaning" => "electricity",
                          "word_type" => "noun"
                        }
                      ]
                    }),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["text"] == "電気"
        assert word["reading"] == "でんき"
        assert word["notes"] == ""
      end)
    end

    test "handles markdown code block wrapper" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    "```json\n" <>
                      Jason.encode!([
                        %{
                          "text" => "食べる",
                          "reading" => "たべる",
                          "meaning" => "to eat",
                          "word_type" => "verb",
                          "verb_group" => "II",
                          "image_text" => "食べます"
                        }
                      ]) <> "\n```",
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["text"] == "食べる"
        assert word["notes"] == "Group II verb (from: 食べます)"
      end)
    end

    test "handles AI refusal" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" => nil,
                  "refusal" => "I cannot process this image"
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:error, message} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert message =~ "refused"
      end)
    end

    test "handles empty response" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" => "",
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:error, message} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert message =~ "empty response"
      end)
    end

    test "handles API error response" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "error" => %{
              "message" => "Rate limit exceeded"
            }
          }

          conn = Plug.Conn.put_status(conn, 429)
          Req.Test.json(conn, response)
        end)

        assert {:error, message} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert message =~ "Rate limit exceeded"
      end)
    end

    test "builds notes from verb_group when AI provides it" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "する",
                        "reading" => "する",
                        "meaning" => "to do",
                        "word_type" => "verb",
                        "verb_group" => "III",
                        "image_text" => "します"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["notes"] == "Group III verb (from: します)"
      end)
    end

    test "leaves notes empty for non-verbs" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "学校",
                        "reading" => "がっこう",
                        "meaning" => "school",
                        "word_type" => "noun"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["notes"] == ""
        assert word["verb_group"] == nil
      end)
    end

    test "normalizes word types to valid values" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "速い",
                        "reading" => "はやい",
                        "meaning" => "fast",
                        "word_type" => "Adjective"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["word_type"] == "adjective"
      end)
    end

    test "normalizes readings by removing punctuation" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "あれ",
                        "reading" => "あれ？",
                        "meaning" => "huh",
                        "word_type" => "expression"
                      },
                      %{
                        "text" => "テスト",
                        "reading" => "てすと 、てすと",
                        "meaning" => "test",
                        "word_type" => "noun"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [first, second]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert first["reading"] == "あれ"
        assert second["reading"] == "てすと/てすと"
      end)
    end

    test "falls back to reading when text is missing" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => nil,
                        "reading" => "アイスクリーム",
                        "meaning" => "ice cream",
                        "word_type" => "noun"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["text"] == "アイスクリーム"
        assert word["reading"] == "アイスクリーム"
        assert word["image_text"] == "アイスクリーム"
        assert word["notes"] == ""
      end)
    end

    test "strips brackets from expressions and preserves original in notes" do
      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!([
                      %{
                        "text" => "[どうぞ]よろしく[ございます]",
                        "reading" => "どうぞよろしくございます",
                        "meaning" => "please be kind to me",
                        "word_type" => "expression"
                      }
                    ]),
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, [word]} =
                 ImageVocabulary.extract_vocabulary(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )

        assert word["text"] == "どうぞよろしくございます"
        assert word["reading"] == "どうぞよろしくございます"
        assert word["image_text"] == "どうぞよろしくございます"
        assert word["notes"] == "[どうぞ]よろしく[ございます]"
      end)
    end

    test "detects PNG image type" do
      png = <<0x89, 0x50, 0x4E, 0x47>> <> String.duplicate(<<0>>, 100)

      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!([]),
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, []} =
                 ImageVocabulary.extract_vocabulary(png,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )
      end)
    end

    test "detects JPEG image type" do
      jpeg = <<0xFF, 0xD8>> <> String.duplicate(<<0>>, 100)

      with_mock_response(fn ->
        Req.Test.stub(ImageVocabulary, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!([]),
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, []} =
                 ImageVocabulary.extract_vocabulary(jpeg,
                   req_opts: [plug: {Req.Test, ImageVocabulary}]
                 )
      end)
    end
  end

  defp without_api_key(fun) do
    original = Application.get_env(:medoru, :openai_api_key)
    Application.put_env(:medoru, :openai_api_key, nil)

    try do
      fun.()
    after
      Application.put_env(:medoru, :openai_api_key, original)
    end
  end

  defp with_mock_response(fun) do
    original = Application.get_env(:medoru, :openai_api_key)
    Application.put_env(:medoru, :openai_api_key, "test-key")

    try do
      fun.()
    after
      Application.put_env(:medoru, :openai_api_key, original)
    end
  end
end
