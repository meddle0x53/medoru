defmodule MedoruWeb.Admin.GrammarDefinitionLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.ContentFixtures
  import Medoru.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture(%{type: "admin"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "Index" do
    test "lists all grammar definitions", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Admin Test Grammar"})

      {:ok, _view, html} = live(conn, ~p"/admin/grammars")

      assert html =~ "Grammar Management"
      assert html =~ grammar.title
    end

    test "has link to create new grammar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/grammars")

      assert html =~ "Add Grammar"
      assert html =~ "/admin/grammars/new"
    end

    test "can delete grammar definition", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/admin/grammars")

      html =
        view
        |> element("button[phx-click='delete'][phx-value-id='#{grammar.id}']")
        |> render_click()

      assert html =~ "Grammar point deleted successfully"
      refute html =~ "To Delete"
    end

    test "filters by JLPT level", %{conn: conn} do
      n5 = grammar_definition_fixture(%{title: "N5 Grammar", jlpt_level: 5})
      _n4 = grammar_definition_fixture(%{title: "N4 Grammar", jlpt_level: 4})

      {:ok, view, _html} = live(conn, ~p"/admin/grammars")

      html =
        view
        |> element("button[phx-click='filter_level'][phx-value-level='5']")
        |> render_click()

      assert html =~ n5.title
      refute html =~ "N4 Grammar"
    end
  end

  describe "Form - New" do
    test "renders form for new grammar definition", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/grammars/new")

      assert html =~ "New Grammar Point"
      assert html =~ "Title"
      assert html =~ "JLPT Level"
    end

    test "creates grammar definition with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/grammars/new")

      # Update title via hook
      render_hook(view, "update_field", %{"field" => "title", "value" => "New Grammar"})

      # Add a pattern element
      view
      |> element("button[phx-click='add_pattern_element'][phx-value-type='literal']")
      |> render_click()

      # Update the pattern element text
      render_hook(view, "update_element_text", %{"index" => "0", "value" => "て"})

      _html =
        view
        |> element("button[phx-click='save']")
        |> render_click()

      assert_redirect(view, ~p"/admin/grammars")
    end

    test "shows errors with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/grammars/new")

      html =
        view
        |> element("button[phx-click='save']")
        |> render_click()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Form - Edit" do
    test "renders form for editing grammar definition", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Edit Me"})

      {:ok, _view, html} = live(conn, ~p"/admin/grammars/#{grammar.id}/edit")

      assert html =~ "Edit Grammar Point"
      assert html =~ grammar.title
    end

    test "updates grammar definition with valid data", %{conn: conn} do
      grammar = grammar_definition_fixture(%{title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/admin/grammars/#{grammar.id}/edit")

      # Update title via hook
      render_hook(view, "update_field", %{"field" => "title", "value" => "Updated Title"})

      _html =
        view
        |> element("button[phx-click='save']")
        |> render_click()

      assert_redirect(view, ~p"/admin/grammars")
    end
  end

  describe "access control" do
    test "non-admin is redirected from admin grammar page", %{conn: conn} do
      user = user_fixture_with_registration()
      conn = log_in_user(conn, user)

      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin/grammars")
    end
  end
end
