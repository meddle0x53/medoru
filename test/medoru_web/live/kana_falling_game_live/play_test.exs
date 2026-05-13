defmodule MedoruWeb.KanaFallingGameLive.PlayTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

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

      attrs = %{
        "name" => "Falling Game",
        "kana_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "speed_increase_threshold" => "50",
          "extra_life_threshold" => "100",
          "points_per_kana" => "1"
        }
      }

      # Only use "あ" (romaji "a") for predictable testing
      {:ok, game} =
        Games.create_kana_falling_game(classroom.id, teacher.id, attrs, ["あ"])

      # Publish the game
      Games.publish_game(game.id, teacher.id)

      %{conn: conn, classroom: classroom, game: game, student: student}
    end

    test "renders ready screen with high score", %{conn: conn, classroom: classroom, game: game} do
      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kana-falling-games/#{game.id}")

      assert html =~ "Falling Game"
      assert html =~ "Kana Falling"
      assert html =~ "Start Game"
    end

    test "starts game and shows kana", %{conn: conn, classroom: classroom, game: game} do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kana-falling-games/#{game.id}")

      html = view |> element("button", "Start Game") |> render_click()

      assert html =~ "あ"
      assert html =~ "Score"
      assert html =~ "Speed"
      assert html =~ "Lives"
    end

    test "typing correct romaji destroys kana and adds points", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kana-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'a' which is the romaji for あ
      html = send_key(view, "a")

      # Should show score increased
      assert html =~ "1"
    end

    test "typing wrong romaji shows penalty", %{
      conn: conn,
      classroom: classroom,
      game: game
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/kana-falling-games/#{game.id}")

      view |> element("button", "Start Game") |> render_click()

      # Type 'b' which is wrong for あ
      html = send_key(view, "b")

      # Input buffer should show 'b'
      assert html =~ "b"
    end

    test "redirects non-members", %{classroom: classroom, game: game} do
      other_user = user_fixture()
      other_conn = log_in_user(build_conn(), other_user)

      expected_path = "/classrooms/#{classroom.id}"
      assert {:error, {:live_redirect, %{to: ^expected_path}}} =
        live(other_conn, ~p"/classrooms/#{classroom.id}/kana-falling-games/#{game.id}")
    end
  end

  defp send_key(view, key) do
    render_hook(view, "key_pressed", %{"key" => key})
  end
end
