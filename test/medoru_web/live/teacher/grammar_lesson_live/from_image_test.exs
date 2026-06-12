defmodule MedoruWeb.Teacher.GrammarLessonLive.FromImageTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  describe "From Image Grammar (admin only)" do
    test "redirects non-admin users", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:error, {:live_redirect, %{to: "/teacher/grammar-lessons"}}} =
        live(conn, ~p"/teacher/grammar-lessons/from-image")
    end

    test "mounts for admin user", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/from-image")
      assert render(view) =~ "Create Grammar Lesson from Image"
    end

    test "shows upload area", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/from-image")
      assert render(view) =~ "Click or drag an image here"
      assert render(view) =~ "Extract Grammar"
    end
  end

  describe "Grammar lesson index shows Create from Image button for admins" do
    test "admin sees Create from Image button", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons")
      assert render(view) =~ "Create from Image"
    end

    test "teacher does not see Create from Image button", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons")
      refute render(view) =~ "Create from Image"
    end
  end
end
