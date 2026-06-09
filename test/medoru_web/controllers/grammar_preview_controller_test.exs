defmodule MedoruWeb.GrammarPreviewControllerTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.ContentFixtures
  import Medoru.AccountsFixtures


  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /api/grammar-preview/:text" do
    test "returns grammar preview data for exact title match", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "te-form", jlpt_level: 5})

      conn = get(conn, ~p"/api/grammar-preview/te-form")

      assert %{
               "id" => id,
               "title" => "te-form",
               "slug" => slug,
               "jlpt_level" => 5,
               "pattern_elements" => pattern_elements,
               "first_example" => first_example,
               "path" => path
             } = json_response(conn, 200)

      assert id == grammar.id
      assert slug == grammar.slug
      assert is_list(pattern_elements)
      assert is_map(first_example)
      assert path == "/grammars/#{grammar.slug}"
    end

    test "returns grammar preview for partial title match", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Vて-form も いいですか", jlpt_level: 5})

      conn = get(conn, ~p"/api/grammar-preview/Vて-form")
      response = json_response(conn, 200)

      assert response["title"] == grammar.title
      assert response["slug"] == grammar.slug
    end

    test "returns 404 when grammar not found", %{conn: conn} do
      conn = get(conn, ~p"/api/grammar-preview/nonexistent-grammar-12345")
      assert response(conn, 404) == ""
    end

    test "returns most frequent grammar when multiple match", %{conn: conn} do
      _less_frequent = grammar_definition_fixture(%{title: "Common Grammar", jlpt_level: 4, frequency: 100})
      more_frequent = grammar_definition_fixture(%{title: "Common Grammar Pattern", jlpt_level: 5, frequency: 10})

      conn = get(conn, ~p"/api/grammar-preview/Common")
      response = json_response(conn, 200)

      assert response["id"] == more_frequent.id
    end
  end
end
