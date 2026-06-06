defmodule MedoruWeb.LearnedGrammarsLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Learning

  describe "learned grammars index" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders empty state when no grammar learned", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/#{user.id}/grammars")

      assert html =~ "No grammar learned yet"
      assert html =~ "Browse Grammar"
    end

    test "renders learned grammar definitions", %{conn: conn, user: user} do
      grammar = grammar_definition_fixture(%{title: "〜てもいい", slug: "te-mo-ii"})
      {:ok, _} = Learning.track_grammar_learned(user.id, grammar.id)

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.id}/grammars")

      assert html =~ "〜てもいい"
      assert html =~ "1 grammar learned"
    end

    test "renders grammar with JLPT badge", %{conn: conn, user: user} do
      grammar = grammar_definition_fixture(%{title: "〜たら", slug: "tara", jlpt_level: 4})
      {:ok, _} = Learning.track_grammar_learned(user.id, grammar.id)

      {:ok, _lv, html} = live(conn, ~p"/users/#{user.id}/grammars")

      assert html =~ "〜たら"
      assert html =~ "N4"
    end

    test "paginates learned grammar", %{conn: conn, user: user} do
      # Create 35 grammar definitions to test pagination
      for i <- 1..35 do
        grammar =
          grammar_definition_fixture(%{
            title: "Grammar #{i}",
            slug: "grammar-#{i}",
            frequency: i
          })

        {:ok, _} = Learning.track_grammar_learned(user.id, grammar.id)
      end

      {:ok, lv, html} = live(conn, ~p"/users/#{user.id}/grammars")

      assert html =~ "35 grammar learned"
      assert html =~ "Page 1 of 2"
      # Page 1 should have some grammar items
      assert html =~ "Grammar 1"

      # Navigate to page 2
      html = render_click(lv, "change_page", %{"page" => "2"})

      assert html =~ "Page 2 of 2"
      # Page 2 should have the remaining items
      assert html =~ "Grammar"
    end

    test "links to grammar show page", %{conn: conn, user: user} do
      grammar = grammar_definition_fixture(%{title: "〜ば", slug: "ba"})
      {:ok, _} = Learning.track_grammar_learned(user.id, grammar.id)

      {:ok, lv, _html} = live(conn, ~p"/users/#{user.id}/grammars")

      assert lv
             |> element("a[href='/grammars/ba']")
             |> has_element?()
    end

    test "shows other user's learned grammar", %{conn: conn} do
      other_user = user_fixture()
      grammar = grammar_definition_fixture(%{title: "〜のに", slug: "noni"})
      {:ok, _} = Learning.track_grammar_learned(other_user.id, grammar.id)

      {:ok, _lv, html} = live(conn, ~p"/users/#{other_user.id}/grammars")

      assert html =~ "〜のに"
      assert html =~ "1 grammar learned"
    end
  end
end
