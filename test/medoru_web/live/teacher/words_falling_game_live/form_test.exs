defmodule MedoruWeb.Teacher.WordsFallingGameLive.FormTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Classrooms

  defp search_and_add_word(view, word_text) do
    view
    |> element("input[name='query']")
    |> render_change(%{"query" => word_text})

    view
    |> element("button[phx-click='add_word']")
    |> render_click()
  end

  describe "Create" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_fixture(%{text: "学校", meaning: "school", reading: "がっこう"})
      word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい"})
      word_fixture(%{text: "学生", meaning: "student", reading: "がくせい"})
      word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      %{conn: conn, teacher: teacher, classroom: classroom}
    end

    test "renders form", %{conn: conn, classroom: classroom} do
      {:ok, _view, html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/words-falling-games/new")

      assert html =~ "Create Words Cascade Game"
      assert html =~ "Game Name"
      assert html =~ "Initial Speed"
      assert html =~ "Word Selection"
      assert html =~ "Game Mode"
    end

    test "creates game with valid data", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/words-falling-games/new")

      # Search and add words
      search_and_add_word(view, "日本")
      search_and_add_word(view, "学校")
      search_and_add_word(view, "先生")
      search_and_add_word(view, "学生")
      search_and_add_word(view, "本")

      view
      |> form("form[phx-submit='save']", %{
        "name" => "My Words Game",
        "initial_speed" => "3",
        "lives" => "5",
        "speed_increase_threshold" => "50",
        "extra_life_threshold" => "100",
        "game_mode" => "0"
      })
      |> render_submit()

      assert_redirected(view, ~p"/teacher/classrooms/#{classroom.id}?tab=games")
    end

    test "shows error for missing name", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/words-falling-games/new")

      # Add some words
      search_and_add_word(view, "日本")
      search_and_add_word(view, "学校")
      search_and_add_word(view, "先生")
      search_and_add_word(view, "学生")
      search_and_add_word(view, "本")

      html =
        view
        |> form("form[phx-submit='save']", %{"name" => ""})
        |> render_submit()

      assert html =~ "Name is required"
    end

    test "shows error for fewer than 5 words", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/words-falling-games/new")

      # Add only 2 words
      search_and_add_word(view, "日本")
      search_and_add_word(view, "学校")

      html =
        view
        |> form("form[phx-submit='save']", %{"name" => "Test Game"})
        |> render_submit()

      assert html =~ "Select at least 5 words"
    end
  end
end
