defmodule Medoru.AI.KanjiEnrichmentTest do
  use ExUnit.Case, async: false

  alias Medoru.AI.KanjiEnrichment

  describe "enrich/2" do
    setup do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original)
      end)
    end

    test "returns normalized main kanji fields" do
      Req.Test.stub(KanjiEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "meanings" => "sun, day, Japan",
                    "stroke_count" => "4",
                    "jlpt_level" => "5",
                    "school_level" => "1",
                    "frequency" => "100",
                    "radicals" => "日",
                    "translations" => %{
                      "bg" => %{"meanings" => "слънце, ден"},
                      "ja" => %{"meanings" => "太陽、日、日本"}
                    }
                  }),
                "refusal" => nil
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, data} =
               KanjiEnrichment.enrich("日",
                 req_opts: [plug: {Req.Test, KanjiEnrichment}]
               )

      assert data["meanings"] == "sun, day, Japan"
      assert data["stroke_count"] == 4
      assert data["jlpt_level"] == 5
      assert data["school_level"] == 1
      assert data["frequency"] == 100
      assert data["radicals"] == ["日"]
      assert data["translations"]["bg"]["meanings"] == ["слънце", "ден"]
      assert data["translations"]["ja"]["meanings"] == ["太陽", "日", "日本"]
    end

    test "returns error when API key is missing" do
      Application.put_env(:medoru, :openai_api_key, nil)

      assert {:error, message} = KanjiEnrichment.enrich("日")
      assert message =~ "API key is not configured"
    end
  end

  describe "enrich_readings/2" do
    setup do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original)
      end)
    end

    test "returns normalized readings" do
      Req.Test.stub(KanjiEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "readings" => [
                      %{"reading_type" => "on", "reading" => "ニチ", "romaji" => "nichi"},
                      %{"reading_type" => "kun", "reading" => "ひ", "romaji" => "hi"}
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
               KanjiEnrichment.enrich_readings("日",
                 req_opts: [plug: {Req.Test, KanjiEnrichment}]
               )

      readings = data["readings"]
      assert length(readings) == 2

      [on, kun] = readings
      assert on["reading_type"] == "on"
      assert on["reading"] == "ニチ"
      assert on["romaji"] == "nichi"

      assert kun["reading_type"] == "kun"
      assert kun["reading"] == "ひ"
      assert kun["romaji"] == "hi"
    end
  end

  describe "enrich_stroke_data/2" do
    setup do
      original = Application.get_env(:medoru, :openai_api_key)
      Application.put_env(:medoru, :openai_api_key, "test-key")

      on_exit(fn ->
        Application.put_env(:medoru, :openai_api_key, original)
      end)
    end

    test "returns local KanjiVG data when available" do
      assert {:ok, data} = KanjiEnrichment.enrich_stroke_data("一")

      assert data["source"] == "kanjivg"
      assert is_map(data["stroke_data"])
      assert data["stroke_data"]["bounds"]["width"] == 109
      assert is_list(data["stroke_data"]["strokes"])
      assert length(data["stroke_data"]["strokes"]) > 0
    end

    test "falls back to AI when local data is missing" do
      Req.Test.stub(KanjiEnrichment, fn conn ->
        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "stroke_data" => %{
                      "bounds" => %{
                        "width" => 109,
                        "height" => 109,
                        "viewBox" => "0 0 109 109"
                      },
                      "strokes" => [
                        %{
                          "path" => "M10,54 L99,54",
                          "order" => 1,
                          "type" => "straight",
                          "direction" => "left-to-right"
                        }
                      ]
                    }
                  }),
                "refusal" => nil
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      # Use a character that is not in the local KanjiVG dataset.
      assert {:ok, data} =
               KanjiEnrichment.enrich_stroke_data("\uFFFF",
                 req_opts: [plug: {Req.Test, KanjiEnrichment}]
               )

      assert data["source"] == "ai"
      assert data["stroke_data"]["bounds"]["width"] == 109
      assert [stroke] = data["stroke_data"]["strokes"]
      assert stroke["path"] == "M10,54 L99,54"
      assert stroke["order"] == 1
    end
  end
end
