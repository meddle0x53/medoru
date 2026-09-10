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

    test "shows type badge and filters by entry type", %{conn: conn} do
      pattern_grammar = grammar_definition_fixture(%{title: "Pattern Entry", jlpt_level: 5})
      text_grammar = grammar_definition_fixture(%{title: "Text Entry", entry_type: "text"})

      {:ok, _view, html} = live(conn, ~p"/grammars")
      assert html =~ "Pattern"
      assert html =~ "Text"

      {:ok, view, _html} = live(conn, ~p"/grammars?type=text")
      html = render(view)
      assert html =~ text_grammar.title
      refute html =~ pattern_grammar.title
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

    test "text entry renders sections and hides the validation box", %{conn: conn} do
      grammar =
        grammar_definition_fixture(%{
          title: "Honorific Overview",
          entry_type: "text",
          description: "Intro text.",
          explanation_sections: ["First **section**.", "Second section."],
          examples: [
            %{
              "sentence" => "食べて",
              "reading" => "たべて",
              "meaning" => "eating"
            }
          ]
        })

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ "Honorific Overview"
      assert html =~ "Intro text."
      assert html =~ "First <strong>section</strong>."
      assert html =~ "Second section."
      assert html =~ "食べて"
      refute html =~ "Try Your Own Example"
    end

    test "text entry with a display-only pattern shows pattern but no validation", %{
      conn: conn
    } do
      grammar =
        grammar_definition_fixture(%{
          title: "Text With Pattern",
          entry_type: "text",
          pattern_elements: [%{"type" => "literal", "text" => "こと"}]
        })

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ "Pattern"
      assert html =~ "こと"
      refute html =~ "Try Your Own Example"
    end

    test "pattern entry without description but with sections renders explanation", %{
      conn: conn
    } do
      grammar =
        grammar_definition_fixture(%{
          title: "Sectioned Pattern",
          description: nil,
          explanation_sections: ["Only a section."]
        })

      {:ok, _view, html} = live(conn, ~p"/grammars/#{grammar.slug}")

      assert html =~ "Explanation"
      assert html =~ "Only a section."
      assert html =~ "Try Your Own Example"
    end
  end
end
