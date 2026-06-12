defmodule Medoru.AI.ImageGrammarTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.ImageGrammar

  @dummy_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
               0x44, 0x52>>

  describe "extract_grammar/2" do
    test "returns error when API key is not configured" do
      without_api_key(fn ->
        assert {:error, message} = ImageGrammar.extract_grammar(@dummy_png)
        assert message =~ "API key is not configured"
      end)
    end

    test "handles successful response with title and sections" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "title" => "IV. Grammar Notes",
                      "sections" => [
                        %{
                          "number" => 1,
                          "title" => "Verb Groups",
                          "description" => "Japanese verbs conjugate...",
                          "examples" => [],
                          "is_grammar_pattern" => false
                        },
                        %{
                          "number" => 2,
                          "title" => "V て-form",
                          "description" => "The verb form that ends with て...",
                          "examples" => [
                            %{
                              "sentence" => "かきます",
                              "reading" => "かきます",
                              "meaning" => "write"
                            }
                          ],
                          "is_grammar_pattern" => true
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

        assert {:ok, data} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert data["title"] == "IV. Grammar Notes"
        assert length(data["sections"]) == 2

        [section1, section2] = data["sections"]
        assert section1["title"] == "Verb Groups"
        assert section1["is_grammar_pattern"] == false
        assert section1["examples"] == []

        assert section2["title"] == "V て-form"
        assert section2["is_grammar_pattern"] == true
        assert length(section2["examples"]) == 1
      end)
    end

    test "handles markdown code block wrapper" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    "```json\n" <>
                      Jason.encode!(%{
                        "title" => "Grammar",
                        "sections" => []
                      }) <> "\n```",
                  "refusal" => nil
                }
              }
            ]
          }

          Req.Test.json(conn, response)
        end)

        assert {:ok, data} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert data["title"] == "Grammar"
      end)
    end

    test "handles AI refusal" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
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
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert message =~ "refused"
      end)
    end

    test "handles empty response" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" => "",
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:error, message} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert message =~ "empty response"
      end)
    end

    test "handles API error response" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          conn = Plug.Conn.put_status(conn, 429)

          Req.Test.json(conn, %{
            "error" => %{
              "message" => "Rate limit exceeded"
            }
          })
        end)

        assert {:error, message} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert message =~ "Rate limit exceeded"
      end)
    end

    test "normalizes section number from string" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "title" => "Test",
                      "sections" => [
                        %{
                          "number" => "3",
                          "title" => "Section",
                          "description" => "text",
                          "examples" => []
                        }
                      ]
                    }),
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, data} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        section = hd(data["sections"])
        assert section["number"] == 3
      end)
    end

    test "defaults title when missing" do
      with_mock_response(fn ->
        Req.Test.stub(ImageGrammar, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "sections" => []
                    }),
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, data} =
                 ImageGrammar.extract_grammar(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageGrammar}]
                 )

        assert data["title"] == "Grammar Lesson"
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
