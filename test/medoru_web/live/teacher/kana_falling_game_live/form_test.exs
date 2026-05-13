defmodule MedoruWeb.Teacher.KanaFallingGameLive.FormTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Classrooms

  describe "Create" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      %{conn: conn, teacher: teacher, classroom: classroom}
    end

    test "renders form", %{conn: conn, classroom: classroom} do
      {:ok, _view, html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kana-falling-games/new")

      assert html =~ "Create Kana Falling Game"
      assert html =~ "Game Name"
      assert html =~ "Initial Speed"
      assert html =~ "Select Kana"
    end

    test "creates game with valid data", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kana-falling-games/new")

      view
      |> form("form", %{
        "name" => "My Falling Game",
        "initial_speed" => "3",
        "lives" => "5",
        "speed_increase_threshold" => "50",
        "extra_life_threshold" => "100",
        "points_per_kana" => "2"
      })
      |> render_submit()

      # Select some kana first
      view
      |> element("button[phx-value-character='あ']")
      |> render_click()

      view
      |> element("button[phx-value-character='い']")
      |> render_click()

      view
      |> element("button[phx-value-character='う']")
      |> render_click()

      view
      |> form("form", %{
        "name" => "My Falling Game",
        "initial_speed" => "3",
        "lives" => "5",
        "speed_increase_threshold" => "50",
        "extra_life_threshold" => "100",
        "points_per_kana" => "2"
      })
      |> render_submit()

      assert_redirected(view, ~p"/teacher/classrooms/#{classroom.id}?tab=games")
    end

    test "shows error for missing name", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kana-falling-games/new")

      # Select kana
      view
      |> element("button[phx-value-character='あ']")
      |> render_click()

      html =
        view
        |> form("form", %{"name" => ""})
        |> render_submit()

      assert html =~ "Name is required"
    end

    test "shows error for no selected kana", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/kana-falling-games/new")

      html =
        view
        |> form("form", %{"name" => "Test Game"})
        |> render_submit()

      assert html =~ "Select at least one kana"
    end
  end
end
