defmodule MedoruWeb.GrammarDefinitionLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Learning

  describe "Index" do
    test "lists all grammar definitions", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "te-form", jlpt_level: 5})

      {:ok, _view, html} = live(conn, ~p"/grammars")

      assert html =~ "Grammar"
      assert html =~ grammar.title
      assert html =~ "N5"
    end

    test "filters grammar by JLPT level", %{conn: conn} do
      n5_grammar = grammar_definition_fixture(%{title: "N5 Grammar", jlpt_level: 5})
      n4_grammar = grammar_definition_fixture(%{title: "N4 Grammar", jlpt_level: 4})

      {:ok, view, _html} = live(conn, ~p"/grammars?level=4")

      html = render(view)
      assert html =~ n4_grammar.title
      refute html =~ n5_grammar.title
    end

    test "shows pagination when many grammar definitions", %{conn: conn} do
      # Create enough grammar definitions to trigger pagination
      for i <- 1..35 do
        grammar_definition_fixture(%{title: "Grammar #{i}", jlpt_level: 5})
      end

      {:ok, _view, html} = live(conn, ~p"/grammars")

      assert html =~ "Page 1 of 2"
      assert html =~ "Next"
    end

    test "searches grammar by title", %{conn: conn} do
      grammar_definition_fixture(%{title: "te-form connection", jlpt_level: 5})
      grammar_definition_fixture(%{title: "ta-form past", jlpt_level: 5})

      {:ok, view, _html} = live(conn, ~p"/grammars")

      html =
        view
        |> form("form[phx-submit='search']", %{search: %{query: "te-form"}})
        |> render_submit()

      assert html =~ "te-form connection"
      refute html =~ "ta-form past"
    end

    test "navigates to grammar detail page", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Test Grammar", jlpt_level: 5})

      {:ok, view, _html} = live(conn, ~p"/grammars")

      view
      |> element("a[href=\"/grammars/#{grammar.slug}\"]")
      |> render_click()

      assert_redirect(view, ~p"/grammars/#{grammar.slug}")
    end

    test "shows grammar link in navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/grammars")

      assert html =~ "Grammar"
    end

    test "shows learned badge for learned grammar definitions", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      grammar = grammar_definition_fixture(%{title: "Learned Grammar", jlpt_level: 5})

      assert {:ok, _} = Learning.track_grammar_learned(user.id, grammar.id)

      {:ok, view, _html} = live(conn, ~p"/grammars")

      assert has_element?(view, "span.badge.badge-success", "Learned")
      assert render(view) =~ "Learned Grammar"
    end

    test "does not show learned badge for grammar definitions not learned", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      grammar_definition_fixture(%{title: "Unlearned Grammar", jlpt_level: 5})

      {:ok, view, _html} = live(conn, ~p"/grammars")

      assert render(view) =~ "Unlearned Grammar"
      refute has_element?(view, "span.badge.badge-success", "Learned")
    end
  end

  describe "Show" do
    test "displays grammar definition details", %{conn: conn} do
      grammar =
        grammar_definition_fixture(%{
          title: "te-form",
          jlpt_level: 5,
          description: "The te-form connects verbs.",
          examples: [
            %{
              "sentence" => "食べて",
              "reading" => "たべて",
              "meaning" => "eating"
            }
          ]
        })

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ grammar.title
      assert html =~ "N5"
      assert html =~ "Pattern"
      assert html =~ "Explanation"
      assert html =~ grammar.description
      assert html =~ "Examples"
      assert html =~ "食べて"
      assert html =~ "たべて"
      assert html =~ "eating"
    end

    test "shows try your own example section", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Test Grammar"})

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ "Try Your Own Example"
      assert html =~ "validate_sentence"
    end

    test "validates user example sentence", %{conn: conn} do
      grammar =
        grammar_definition_fixture(%{
          title: "Test Grammar",
          pattern_elements: [
            %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
            %{"type" => "literal", "text" => "いる"}
          ]
        })

      {:ok, view, _html} = live(conn, ~p"/grammars/#{grammar.slug}")

      html =
        view
        |> form("form[phx-submit='validate_sentence']", %{sentence: "test"})
        |> render_submit()

      assert html =~ "Validate"
    end

    test "has back link to grammar list", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Test Grammar", jlpt_level: 5})

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ "Back to Grammar"
    end

    test "navigates back to grammar list", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Test Grammar", jlpt_level: 5})

      {:ok, view, _html} = live(conn, ~p"/grammars/#{grammar.slug}")

      view
      |> element("a", "Back to Grammar")
      |> render_click()

      assert_redirect(view, ~p"/grammars")
    end

    test "returns error for non-existent slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/grammars"}}} =
               live(conn, ~p"/grammars/nonexistent-slug")
    end
  end
end
