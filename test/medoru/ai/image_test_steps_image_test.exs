defmodule Medoru.AI.ImageTestStepsImageTest do
  use ExUnit.Case, async: false

  alias Medoru.AI.ImageTestSteps

  @dummy_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
               0x44, 0x52>>

  test "extracts example and 4 steps from provided image format" do
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
                      },
                      %{
                        "number" => 3,
                        "words" => "タワポンさん / 先生",
                        "correct_answer" => "タワポンさんは先生じゃありません。"
                      },
                      %{
                        "number" => 4,
                        "words" => "シュミットさん / アメリカ人",
                        "correct_answer" => "シュミットさんはアメリカ人じゃありません。"
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

      assert data["example"] == "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"
      assert length(data["steps"]) == 4

      [step1 | _] = data["steps"]
      assert step1["words"] == "山田さん / 学生"
      assert step1["correct_answer"] == "山田さんは学生じゃありません。"
    after
      Application.put_env(:medoru, :openai_api_key, original)
    end
  end

  test "normalizes ・ separator to /" do
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
                      %{
                        "number" => 1,
                        "words" => "山田さん・学生",
                        "correct_answer" => "山田さんは学生じゃありません。"
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
               ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                 req_opts: [plug: {Req.Test, ImageTestSteps}]
               )

      step = hd(data["steps"])
      assert step["words"] == "山田さん / 学生"
    after
      Application.put_env(:medoru, :openai_api_key, original)
    end
  end

  test "falls back to examples array" do
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
                    "examples" => ["ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"],
                    "steps" => [
                      %{
                        "number" => 1,
                        "words" => "山田さん / 学生",
                        "correct_answer" => "山田さんは学生じゃありません。"
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
               ImageTestSteps.extract_grammar_pattern_steps(@dummy_png,
                 req_opts: [plug: {Req.Test, ImageTestSteps}]
               )

      assert data["example"] == "ミラーさん・銀行員 → ミラーさんは銀行員じゃありません。"
      assert length(data["steps"]) == 1
    after
      Application.put_env(:medoru, :openai_api_key, original)
    end
  end
end
