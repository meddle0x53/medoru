defmodule Medoru.AI.ImageTestStepsTest do
  use ExUnit.Case, async: false

  alias Medoru.AI.ImageTestSteps

  @dummy_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
               0x44, 0x52>>

  describe "extract_grammar_pattern_steps/2" do
    test "returns error when API key is not configured" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      try do
        assert {:error, message} = ImageTestSteps.extract_grammar_pattern_steps(@dummy_png)
        assert message =~ "API key is not configured"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "handles successful response with example and steps" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "example" => "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。",
                      "steps" => [
                        %{
                          "number" => 1,
                          "words" => "山田さん / 学生",
                          "correct_answer" => "山田さんは学生じゃありません。"
                        },
                        %{
                          "number" => 2,
                          "words" => "ワットさん / ドイツ人",
                          "correct_answer" => "ワットさんはドイツ人じゃありません。"
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
                 ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert data["examples"] == ["ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"]
        assert data["example"] == "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"
        assert length(data["steps"]) == 2

        [step1, step2] = data["steps"]
        assert step1["number"] == 1
        assert step1["words"] == "山田さん / 学生"
        assert step1["correct_answer"] == "山田さんは学生じゃありません。"

        assert step2["number"] == 2
        assert step2["words"] == "ワットさん / ドイツ人"
        assert step2["correct_answer"] == "ワットさんはドイツ人じゃありません。"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "handles markdown code block wrapper" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    "```json\n" <>
                      Jason.encode!(%{
                        "example" => "test",
                        "steps" => []
                      }) <> "\n```",
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, data} =
                 ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert data["examples"] == ["test"]
        assert data["example"] == "test"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "handles AI refusal" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" => nil,
                  "refusal" => "I cannot process this image"
                }
              }
            ]
          })
        end)

        assert {:error, message} =
                 ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert message =~ "refused"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "normalizes step number from string" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          Req.Test.json(conn, %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "example" => "",
                      "steps" => [
                        %{"number" => "3", "words" => "a / b", "correct_answer" => "ab"}
                      ]
                    }),
                  "refusal" => nil
                }
              }
            ]
          })
        end)

        assert {:ok, data} =
                 ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        step = hd(data["steps"])
        assert step["number"] == 3
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end
  end

  describe "extract_writing_fill_in_steps/2" do
    test "normalizes multiline examples and answers to single lines" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "examples" => [
                        "あなたは\n（学生）ですか。"
                      ],
                      "steps" => [
                        %{
                          "number" => 1,
                          "template" => "あなたは\n（___）ですか。",
                          "correct_answer" => "あなたは\n（学生）ですか。",
                          "alt_correct_answers" => [
                            "あなたは\n学生ですか。"
                          ]
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
                 ImageTestSteps.extract_writing_fill_in_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert data["examples"] == ["あなたは （学生）ですか。"]

        [step] = data["steps"]
        assert step["template"] == "あなたは （___）ですか。"
        assert step["correct_answer"] == "あなたは （学生）ですか。"
        assert step["alt_correct_answers"] == ["あなたは 学生ですか。"]
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "preserves all lines of multi-line questions joined with spaces" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "examples" => [
                        "例：\nあなたは（学生）ですか。"
                      ],
                      "steps" => [
                        %{
                          "number" => 1,
                          "template" => "これは\n（___）\nですか。",
                          "correct_answer" => "これは\n（学生）\nですか。",
                          "alt_correct_answers" => [
                            "これは\n学生\nですか。"
                          ]
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
                 ImageTestSteps.extract_writing_fill_in_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert data["examples"] == ["例： あなたは（学生）ですか。"]

        [step] = data["steps"]
        assert step["template"] == "これは （___） ですか。"
        assert step["correct_answer"] == "これは （学生） ですか。"
        assert step["alt_correct_answers"] == ["これは 学生 ですか。"]
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "falls back to question field and joins multi-line text" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "examples" => [],
                      "steps" => [
                        %{
                          "number" => 1,
                          "question" => "これは\n（___）\nですか。",
                          "correct_answer" => "これは\n（学生）\nですか。"
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
                 ImageTestSteps.extract_writing_fill_in_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        [step] = data["steps"]
        assert step["template"] == "これは （___） ですか。"
        assert step["correct_answer"] == "これは （学生） ですか。"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "keeps the answer line together with the question line in the template" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      try do
        Req.Test.stub(ImageTestSteps, fn conn ->
          response = %{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "examples" => [
                        "あなたは（学生）ですか。\n……はい、学生です。"
                      ],
                      "steps" => [
                        %{
                          "number" => 1,
                          "template" => "あなたは（ ）ですか。\n……はい、ミラーです。",
                          "correct_answer" => "あなたは（ミラー）ですか。"
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
                 ImageTestSteps.extract_writing_fill_in_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert data["examples"] == ["あなたは（学生）ですか。 ……はい、学生です。"]

        [step] = data["steps"]
        assert step["template"] == "あなたは（___）ですか。 ……はい、ミラーです。"
        assert step["correct_answer"] == "あなたは（ミラー）ですか。"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end
  end
end
