defmodule MedoruWeb.Teacher.KanjiFallingGameLive.FormTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Classrooms

  defp search_and_add_kanji(view, character) do
    view
    |> element("input[name='query']")
    |> render_change(%{"query" => character})

    view
    |> element("button[phx-click='add_kanji'][phx-value-character='#{character}']")
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

      # Create test kanji
      kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :on, reading: "ニチ", romaji: "nichi", usage_notes: ""}
      ])

      kanji_with_readings_fixture(%{character: "月"}, [
        %{reading_type: :on, reading: "ゲツ", romaji: "getsu", usage_notes: ""}
      ])

      kanji_with_readings_fixture(%{character: "火"}, [
        %{reading_type: :on, reading: "カ", romaji: "ka", usage_notes: ""}
      ])

      kanji_with_readings_fixture(%{character: "水"}, [
        %{reading_type: :on, reading: "スイ", romaji: "sui", usage_notes: ""}
      ])

      kanji_with_readings_fixture(%{character: "木"}, [
        %{reading_type: :on, reading: "モク", romaji: "moku", usage_notes: ""}
      ])

      %{conn: conn, teacher: teacher, classroom: classroom}
    end

    test "renders form", %{conn: conn, classroom: classroom} do
      {:ok, _view, html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kanji-falling-games/new")

      assert html =~ "Create Kanji Cascade Game"
      assert html =~ "Game Name"
      assert html =~ "Initial Speed"
      assert html =~ "Select Kanji"
      assert html =~ "Reading Type"
      assert html =~ "On-Screen Keyboard"
    end

    test "creates game with valid data", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kanji-falling-games/new")

      # Search and add kanji
      search_and_add_kanji(view, "日")
      search_and_add_kanji(view, "月")
      search_and_add_kanji(view, "火")
      search_and_add_kanji(view, "水")
      search_and_add_kanji(view, "木")

      view
      |> form("form[phx-submit='save']", %{
        "name" => "My Kanji Game",
        "initial_speed" => "3",
        "lives" => "5",
        "speed_increase_threshold" => "50",
        "extra_life_threshold" => "100",
        "points_per_kanji" => "2",
        "reading_type" => "onyomi",
        "keyboard_type" => "latin"
      })
      |> render_submit()

      assert_redirected(view, ~p"/teacher/classrooms/#{classroom.id}?tab=games")
    end

    test "shows error for missing name", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kanji-falling-games/new")

      # Add some kanji
      search_and_add_kanji(view, "日")
      search_and_add_kanji(view, "月")
      search_and_add_kanji(view, "火")
      search_and_add_kanji(view, "水")
      search_and_add_kanji(view, "木")

      html =
        view
        |> form("form[phx-submit='save']", %{"name" => ""})
        |> render_submit()

      assert html =~ "Name is required"
    end

    test "shows error for fewer than 5 kanji", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kanji-falling-games/new")

      # Add only 2 kanji
      search_and_add_kanji(view, "日")
      search_and_add_kanji(view, "月")

      html =
        view
        |> form("form[phx-submit='save']", %{"name" => "Test Game"})
        |> render_submit()

      assert html =~ "Select at least 5 kanji"
    end
  end
end
