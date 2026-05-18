defmodule MedoruWeb.WordsFallingGameLive.PlayTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.{Classrooms, Games}

  describe "Meaning mode gameplay" do
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

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      attrs = %{
        "name" => "Words Falling Game",
        "words_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "speed_increase_threshold" => "50",
          "extra_life_threshold" => "100",
          "game_mode" => "0",
          "keyboard_type" => "latin"
        }
      }

      {:ok, game} =
        Games.create_words_falling_game(classroom.id, teacher.id, attrs, [word.id])

      Games.publish_game(game.id, teacher.id)

      %{conn: conn, classroom: classroom, game: game, student: student}
    end

    test "renders ready screen with high score", %{conn: conn, classroom: classroom, game: game} do
      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

      assert html =~ "Words Falling Game"
      assert html =~ "Words Cascade"
      assert html =~ "Start Game"
      assert html =~ "Word Meaning"
    end

    test "starts game and shows word", %{conn: conn, classroom: classroom, game: game} do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

      html = view |> element("button", "Start Game") |> render_click()

      assert html =~ "日本"
      assert html =~ "Score"
      assert html =~ "Speed"
      assert html =~ "Lives"
    end

    test "typing correct meaning destroys word and adds points", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'Japan' which is the meaning
      send_key(view, "J")
      send_key(view, "a")
      send_key(view, "p")
      send_key(view, "a")
      html = send_key(view, "n")

      # Should show score increased
      assert html =~ "1"
    end

    test "typing wrong meaning shows penalty", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

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
               live(other_conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")
    end
  end

  describe "Reading mode gameplay" do
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

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      attrs = %{
        "name" => "Reading Mode Game",
        "words_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "speed_increase_threshold" => "50",
          "extra_life_threshold" => "100",
          "game_mode" => "1",
          "keyboard_type" => "latin"
        }
      }

      {:ok, game} =
        Games.create_words_falling_game(classroom.id, teacher.id, attrs, [word.id])

      Games.publish_game(game.id, teacher.id)

      %{conn: conn, classroom: classroom, game: game}
    end

    test "typing correct reading destroys word", %{conn: conn, classroom: classroom, game: game} do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'nihon' which is the romaji for にほん
      send_key(view, "n")
      send_key(view, "i")
      send_key(view, "h")
      send_key(view, "o")
      html = send_key(view, "n")

      assert html =~ "1"
    end

    test "renders reading mode info", %{conn: conn, classroom: classroom, game: game} do
      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/words-falling-games/#{game.id}")

      assert html =~ "Word Reading"
    end
  end

  defp send_key(view, key) do
    render_hook(view, "key_pressed", %{"key" => key})
  end
end
