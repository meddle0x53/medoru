defmodule Medoru.AI.ImageTestStepsMakeQuestionAnswerTest do
  use ExUnit.Case, async: false

  alias Medoru.AI.ImageTestSteps

  @dummy_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
               0x44, 0x52>>

  describe "extract_grammar_make_question_answer_steps/2" do
    test "returns error when API key is not configured" do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, nil)

      try do
        assert {:error, message} =
                 ImageTestSteps.extract_grammar_make_question_answer_steps(@dummy_png)

        assert message =~ "API key is not configured"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end

    test "parses one step per requirement with all five fields and preserves multi-line examples" do
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
                      "examples" => [
                        "この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。",
                        "例2 駅の 前で 写真（いいえ）\r\n駅の前で写真を撮ってもいいですか。\r\n……いいえ、撮ってはいけません。"
                      ],
                      "steps" => [
                        %{
                          "number" => 1,
                          "requirement" => "家の 部屋で 料理（いいえ）",
                          "expected_question" => "家の部屋で料理ができますか。",
                          "expected_answer" => "いいえ、できません。",
                          "expected_question_reading" => "いえのへやでりょうりができますか",
                          "expected_answer_reading" => "いいえ、できません。"
                        },
                        %{
                          "number" => "2",
                          "requirement" => "日本語で 手紙を 書く（はい）",
                          "expected_question" => "日本語で手紙を書けますか。",
                          "expected_answer" => "はい、書けます。",
                          "expected_question_reading" => "にほんごでてがみをかけますか",
                          "expected_answer_reading" => "はいかけます"
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
                 ImageTestSteps.extract_grammar_make_question_answer_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert length(data["steps"]) == 2

        assert data["examples"] == [
                 "この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。",
                 "例2 駅の 前で 写真（いいえ）\n駅の前で写真を撮ってもいいですか。\n……いいえ、撮ってはいけません。"
               ]

        [step1, step2] = data["steps"]

        assert step1["number"] == 1
        assert step1["requirement"] == "家の 部屋で 料理（いいえ）"
        assert step1["expected_question"] == "家の部屋で料理ができますか。"
        assert step1["expected_answer"] == "いいえ、できません。"
        assert step1["expected_question_reading"] == "いえのへやでりょうりができますか"
        assert step1["expected_answer_reading"] == "いいえできません"
        assert step1["examples"] == data["examples"]

        assert step2["number"] == 2
        assert step2["expected_question"] == "日本語で手紙を書けますか。"
        assert step2["expected_question_reading"] == "にほんごでてがみをかけますか"
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
              %{"message" => %{"content" => nil, "refusal" => "I cannot process this image"}}
            ]
          })
        end)

        assert {:error, message} =
                 ImageTestSteps.extract_grammar_make_question_answer_steps(@dummy_png,
                   req_opts: [plug: {Req.Test, ImageTestSteps}]
                 )

        assert message =~ "refused"
      after
        Application.put_env(:medoru, :openai_api_key, original)
      end
    end
  end
end
