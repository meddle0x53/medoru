defmodule Medoru.AI.WordRelationsTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.WordRelations

  setup do
    original_key = Application.get_env(:medoru, :openai_api_key)
    Application.put_env(:medoru, :openai_api_key, "test-key")

    on_exit(fn ->
      Application.put_env(:medoru, :openai_api_key, original_key)
    end)

    :ok
  end

  describe "generate/4" do
    test "returns relation suggestions on successful API response" do
      Req.Test.stub(WordRelations, fn conn ->
        assert conn.method == "POST"

        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{
                    "synonyms" => [
                      %{"text" => "国", "reading" => "くに", "meaning" => "country"}
                    ],
                    "antonyms" => [
                      %{"text" => "外国", "reading" => "がいこく", "meaning" => "foreign country"}
                    ],
                    "expressions" => [
                      %{"text" => "日本に行く", "reading" => "にほんにいく", "meaning" => "go to Japan"}
                    ]
                  })
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, data} =
               WordRelations.generate("日本", "にほん", "Japan", :noun,
                 req_opts: [plug: {Req.Test, WordRelations}]
               )

      assert [synonym] = data["synonyms"]
      assert synonym["text"] == "国"
      assert synonym["reading"] == "くに"

      assert [antonym] = data["antonyms"]
      assert antonym["text"] == "外国"

      assert [expression] = data["expressions"]
      assert expression["text"] == "日本に行く"
    end

    test "returns error for unsupported word types" do
      assert {:error, "Word relations are only supported" <> _} =
               WordRelations.generate("日本", "にほん", "Japan", :expression)
    end

    test "returns error when API key is not configured" do
      Application.put_env(:medoru, :openai_api_key, nil)

      assert {:error, "OpenAI API key is not configured" <> _} =
               WordRelations.generate("日本", "にほん", "Japan", :noun)
    end

    test "returns error on API failure" do
      Req.Test.stub(WordRelations, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, "Request failed: " <> _} =
               WordRelations.generate("日本", "にほん", "Japan", :noun,
                 req_opts: [plug: {Req.Test, WordRelations}]
               )
    end

    test "returns error on non-200 status" do
      Req.Test.stub(WordRelations, fn conn ->
        response = %{"error" => %{"message" => "Invalid API key"}}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(response))
      end)

      assert {:error, "Invalid API key"} =
               WordRelations.generate("日本", "にほん", "Japan", :noun,
                 req_opts: [plug: {Req.Test, WordRelations}]
               )
    end

    test "uses custom prompt when provided" do
      Req.Test.stub(WordRelations, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["messages"]
               |> List.last()
               |> Map.get("content") == "Custom prompt for 日本"

        response = %{
          "choices" => [
            %{
              "message" => %{
                "content" =>
                  Jason.encode!(%{"synonyms" => [], "antonyms" => [], "expressions" => []})
              }
            }
          ]
        }

        Req.Test.json(conn, response)
      end)

      assert {:ok, _} =
               WordRelations.generate("日本", "にほん", "Japan", :noun,
                 custom_prompt: "Custom prompt for %{word_text}",
                 req_opts: [plug: {Req.Test, WordRelations}]
               )
    end
  end

  describe "predefined_prompt/4" do
    test "interpolates word details into the prompt" do
      prompt = WordRelations.predefined_prompt("日本", "にほん", "Japan", :noun)
      assert prompt =~ "日本"
      assert prompt =~ "にほん"
      assert prompt =~ "Japan"
      assert prompt =~ "noun"
      assert prompt =~ "synonyms"
      assert prompt =~ "antonyms"
      assert prompt =~ "expressions"
    end
  end
end
