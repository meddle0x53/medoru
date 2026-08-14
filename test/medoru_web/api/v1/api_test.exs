defmodule MedoruWeb.Api.V1.ApiTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.ContentFixtures

  alias Medoru.Api.Cursor
  alias Medoru.Content

  describe "GET /api/v1/health" do
    test "returns ok", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/health")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    test "includes CORS headers", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/health")

      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, OPTIONS"]
    end
  end

  describe "GET /api/v1/health/db" do
    test "returns ok when database is reachable", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/health/db")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end

  describe "OPTIONS /api/v1/health" do
    test "returns preflight response", %{conn: conn} do
      conn = put_req_header(conn, "origin", "https://example.com")
      conn = options(conn, ~p"/api/v1/health")

      assert response(conn, 204) == ""
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end

  describe "GET /api/v1/kanji" do
    setup do
      _kanji1 = kanji_fixture(%{character: "日", meanings: ["sun", "day"], jlpt_level: 5})
      _kanji2 = kanji_fixture(%{character: "月", meanings: ["moon", "month"], jlpt_level: 5})
      _kanji3 = kanji_fixture(%{character: "火", meanings: ["fire"], jlpt_level: 4})

      :ok
    end

    test "lists kanji ordered by character", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji")

      response = json_response(conn, 200)
      characters = Enum.map(response["items"], & &1["character"])

      assert "日" in characters
      assert "月" in characters
      assert "火" in characters
      assert response["next_cursor"] == nil
    end

    test "filters by jlpt_level", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji?jlpt_level=5")

      response = json_response(conn, 200)
      characters = Enum.map(response["items"], & &1["character"])

      assert "日" in characters
      assert "月" in characters
      refute "火" in characters
    end

    test "respects limit", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji?limit=2")

      response = json_response(conn, 200)

      assert length(response["items"]) == 2
      assert response["next_cursor"] != nil
    end

    test "paginates with cursor", %{conn: conn} do
      first_conn = get(conn, ~p"/api/v1/kanji?limit=2")
      first_response = json_response(first_conn, 200)
      cursor = first_response["next_cursor"]
      assert cursor != nil

      second_conn = get(conn, ~p"/api/v1/kanji?limit=2&cursor=#{cursor}")
      second_response = json_response(second_conn, 200)

      first_characters = Enum.map(first_response["items"], & &1["character"])
      second_characters = Enum.map(second_response["items"], & &1["character"])

      assert length(second_response["items"]) == 1
      assert Enum.all?(second_characters, &(&1 not in first_characters))
    end

    test "returns 400 for invalid cursor", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji?cursor=not-a-valid-cursor")

      assert json_response(conn, 400)["errors"] != nil
    end

    test "returns 400 for cursor with mismatched filters", %{conn: conn} do
      cursor = Cursor.encode(%{"character" => "日", "jlpt_level" => 5})

      conn = get(conn, ~p"/api/v1/kanji?jlpt_level=4&cursor=#{cursor}")

      assert json_response(conn, 400)["errors"] != nil
    end

    test "includes bg_meanings when requested", %{conn: conn} do
      kanji = Content.get_kanji_by_character("日") || raise "test kanji not found"

      {:ok, _} =
        Content.update_kanji(
          kanji,
          %{translations: %{"bg" => %{"meanings" => ["слънце", "ден"]}}}
        )

      conn = get(conn, ~p"/api/v1/kanji?include=bg_meanings")

      response = json_response(conn, 200)
      item = Enum.find(response["items"], &(&1["character"] == "日"))

      assert item["bg_meanings"] == ["слънце", "ден"]
    end

    test "ignores unknown include values", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji?include=unknown")

      response = json_response(conn, 200)
      item = hd(response["items"])

      assert item["bg_meanings"] == nil
    end
  end

  describe "GET /api/v1/kanji/character/:character" do
    setup do
      kanji = kanji_fixture(%{character: "日", meanings: ["sun", "day"], jlpt_level: 5})
      {:ok, kanji: kanji}
    end

    test "returns kanji detail", %{conn: conn, kanji: kanji} do
      conn = get(conn, ~p"/api/v1/kanji/character/#{kanji.character}")

      response = json_response(conn, 200)

      assert response["character"] == "日"
      assert response["meanings"] == ["sun", "day"]
      assert response["stroke_count"] == kanji.stroke_count
    end

    test "includes stroke_data and bg_meanings when requested", %{conn: conn, kanji: kanji} do
      {:ok, _} =
        Content.update_kanji(
          kanji,
          %{
            translations: %{"bg" => %{"meanings" => ["слънце"]}},
            stroke_data: %{"paths" => ["M0 0 L10 10"]}
          }
        )

      conn = get(conn, ~p"/api/v1/kanji/character/#{kanji.character}?include=bg_meanings")

      response = json_response(conn, 200)

      assert response["bg_meanings"] == ["слънце"]
      assert response["stroke_data"] == %{"paths" => ["M0 0 L10 10"]}
    end

    test "returns 404 for missing kanji", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/kanji/character/不存在")

      assert json_response(conn, 404)["errors"] != nil
    end
  end

  describe "GET /api/v1/openapi.json" do
    test "serves the OpenAPI spec", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/openapi.json")

      response = json_response(conn, 200)

      assert response["info"]["title"] == "Medoru API"
      assert response["paths"]["/api/v1/kanji"]
    end
  end

  describe "GET /api/v1/docs" do
    test "serves Swagger UI", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/docs")

      assert response(conn, 200) =~ "swagger-ui"
    end
  end
end
