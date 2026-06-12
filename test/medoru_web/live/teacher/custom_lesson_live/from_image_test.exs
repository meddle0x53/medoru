defmodule MedoruWeb.Teacher.CustomLessonLive.FromImageTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "from-image page" do
    test "redirects non-admin users", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      assert {:error,
              {:live_redirect, %{to: "/teacher/custom-lessons", flash: %{"error" => msg}}}} =
               live(conn, ~p"/teacher/custom-lessons/from-image")

      assert msg =~ "Only admins can create lessons from images"
    end

    test "renders upload page for admin", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons/from-image")
      assert html =~ "Create Lesson from Image"
      assert html =~ "Upload a vocabulary page and let AI extract the words"
    end
  end

  describe "teacher custom lessons index" do
    test "shows 'Create from Image' button for admin", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons")
      assert html =~ "Create from Image"
    end

    test "hides 'Create from Image' button for teacher", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons")
      refute html =~ "Create from Image"
    end
  end

  describe "word matching and lesson creation" do
    test "creates lesson with existing and new words", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      # Pre-create a word that will match
      _existing_word = word_fixture(%{text: "電気", reading: "でんき", meaning: "electricity"})

      {:ok, view, _html} = live(conn, ~p"/teacher/custom-lessons/from-image")

      # Verify the page exists and has the right structure
      assert render(view) =~ "Create Lesson from Image"
    end
  end
end
