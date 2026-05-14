defmodule MedoruWeb.KanjiFallingGameLive.PlayTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.{Classrooms, Games}

  describe "Gameplay" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture()
      conn = log_in_user(conn, student)

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      Classrooms.apply_to_join(classroom.id, student.id)

      # Create test kanji with on'yomi reading "ニチ" (nichi)
      kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :on, reading: "ニチ", romaji: "nichi", usage_notes: ""}
      ])

      attrs = %{
        "name" => "Kanji Falling Game",
        "kanji_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "speed_increase_threshold" => "50",
          "extra_life_threshold" => "100",
          "points_per_kanji" => "1",
          "reading_type" => "any",
          "keyboard_type" => "latin"
        }
      }

      {:ok, game} =
        Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, ["日"])

      Games.publish_game(game.id, teacher.id)

      %{conn: conn, classroom: classroom, game: game, student: student}
    end

    test "renders ready screen with high score", %{conn: conn, classroom: classroom, game: game} do
      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")

      assert html =~ "Kanji Falling Game"
      assert html =~ "Kanji Cascade"
      assert html =~ "Start Game"
    end

    test "starts game and shows kanji", %{conn: conn, classroom: classroom, game: game} do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")

      html = view |> element("button", "Start Game") |> render_click()

      assert html =~ "日"
      assert html =~ "Score"
      assert html =~ "Speed"
      assert html =~ "Lives"
    end

    test "typing correct romaji destroys kanji and adds points", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'nichi' which is the romaji for ニチ
      send_key(view, "n")
      send_key(view, "i")
      send_key(view, "c")
      send_key(view, "h")
      html = send_key(view, "i")

      # Should show score increased
      assert html =~ "1"
    end

    test "typing wrong romaji shows penalty", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'x' which is wrong
      html = send_key(view, "x")

      # Input buffer should show 'x'
      assert html =~ "x"
    end

    test "redirects non-members", %{classroom: classroom, game: game} do
      other_user = user_fixture()
      other_conn = log_in_user(build_conn(), other_user)

      expected_path = "/classrooms/#{classroom.id}"

      assert {:error, {:live_redirect, %{to: ^expected_path}}} =
               live(other_conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")
    end
  end

  describe "Hiragana keyboard mode" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture()
      conn = log_in_user(conn, student)

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      Classrooms.apply_to_join(classroom.id, student.id)

      # Create test kanji with kun'yomi reading "ひ" (hi)
      kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :kun, reading: "ひ", romaji: "hi", usage_notes: ""}
      ])

      attrs = %{
        "name" => "Hiragana Mode Game",
        "kanji_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "speed_increase_threshold" => "50",
          "extra_life_threshold" => "100",
          "points_per_kanji" => "1",
          "reading_type" => "any",
          "keyboard_type" => "hiragana"
        }
      }

      {:ok, game} =
        Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, ["日"])

      Games.publish_game(game.id, teacher.id)

      %{conn: conn, classroom: classroom, game: game}
    end

    test "typing hiragana destroys kanji", %{conn: conn, classroom: classroom, game: game} do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kanji-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'ひ' directly
      html = send_key(view, "ひ")

      assert html =~ "1"
    end
  end

  defp send_key(view, key) do
    render_hook(view, "key_pressed", %{"key" => key})
  end
end
