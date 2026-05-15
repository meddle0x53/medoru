defmodule MedoruWeb.ClassroomGameLive.PlayTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.Classrooms
  alias Medoru.Games
  alias Medoru.Repo

  describe "Play memory card game" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})

      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      words = Enum.map(1..8, fn _ -> word_fixture() end)
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      attrs = %{
        "name" => "Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10,
          "meaning_required_for_collection" => false,
          "pronunciation_required_for_collection" => false,
          "meaning_or_pronunciation_required_for_collection" => false
        }
      }

      {:ok, game} =
        Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)

      {:ok, _} = Games.publish_game(game.id, teacher.id)

      %{teacher: teacher, student: student, classroom: classroom, game: game, words: words}
    end

    test "renders game for approved member", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      assert html =~ game.name
      assert html =~ "Memory Card Game"
      assert html =~ "attempts"
    end

    test "redirects non-member", %{conn: conn, classroom: classroom, game: game} do
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      assert {:error, {:live_redirect, %{to: "/classrooms"}}} =
               live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")
    end

    test "redirects pending member", %{conn: conn, classroom: classroom, game: game} do
      pending_student = user_fixture(%{type: "student"})
      {:ok, _} = Classrooms.apply_to_join(classroom.id, pending_student.id)
      conn = log_in_user(conn, pending_student)

      assert {:error, {:live_redirect, %{to: "/classrooms"}}} =
               live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")
    end

    test "redirects for unpublished game", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      {:ok, _} = Games.unpublish_game(game.id, classroom.teacher_id)
      conn = log_in_user(conn, student)
      expected_path = "/classrooms/#{classroom.id}?tab=games"

      assert {:error, {:live_redirect, %{to: ^expected_path}}} =
               live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")
    end

    test "flip card reveals it", %{conn: conn, student: student, classroom: classroom, game: game} do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      html =
        view |> element("button[phx-click='flip_card'][phx-value-position='0']") |> render_click()

      assert html =~ "bg-base-100"
    end

    test "flipping two matching cards collects them", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      # Get session to find matching positions
      session = Games.get_user_session(game.id, student.id)
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)

      matching_pos =
        Enum.find_index(Enum.with_index(card_positions), fn {id, idx} ->
          idx != 0 and id == word_id
        end)

      # Flip first card
      view |> element("button[phx-click='flip_card'][phx-value-position='0']") |> render_click()
      # Flip matching card
      html =
        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{matching_pos}']")
        |> render_click()

      assert html =~ "Match!"
      assert html =~ "hero-check"
    end

    test "flipping two non-matching cards shows no match then closes", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      session = Games.get_user_session(game.id, student.id)
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)

      # Find a non-matching position
      non_matching_pos =
        Enum.find_index(Enum.with_index(card_positions), fn {id, idx} ->
          idx != 0 and id != word_id
        end)

      # Flip both
      view |> element("button[phx-click='flip_card'][phx-value-position='0']") |> render_click()

      html =
        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{non_matching_pos}']")
        |> render_click()

      # Both should be flipped (revealed)
      assert html =~ "bg-base-100"

      # Verify session state via DB
      updated_session = Repo.reload!(session)
      assert updated_session.attempts_used == 1
    end

    test "game over banner shows when attempts exhausted", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      # Set session to have only 1 attempt left
      session = Games.get_user_session(game.id, student.id)

      session
      |> Games.MemoryCardSession.changeset(%{attempts_used: 9})
      |> Repo.update!()

      session = Games.get_user_session(game.id, student.id)
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)

      non_matching_pos =
        Enum.find_index(Enum.with_index(card_positions), fn {id, idx} ->
          idx != 0 and id != word_id
        end)

      # Flip two non-matching cards to exhaust the last attempt
      view |> element("button[phx-click='flip_card'][phx-value-position='0']") |> render_click()

      html =
        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{non_matching_pos}']")
        |> render_click()

      assert html =~ "Game Over!"
    end

    test "reset game button starts fresh", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      # Complete the game by collecting all pairs through the UI
      session = Games.get_user_session(game.id, student.id)
      card_positions = session.cards_state["card_positions"]

      # Build map of word_id -> [positions]
      positions_by_word =
        card_positions
        |> Enum.with_index()
        |> Enum.group_by(fn {word_id, _idx} -> word_id end, fn {_word_id, idx} -> idx end)

      for {_word_id, [pos1, pos2]} <- positions_by_word do
        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{pos1}']")
        |> render_click()

        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{pos2}']")
        |> render_click()
      end

      # After all pairs collected, game over banner should show
      html = render(view)
      assert html =~ "Play Again"

      # Click reset
      html = view |> element("button", "Play Again") |> render_click()
      assert html =~ "Good luck"
    end
  end

  describe "Play kana memory card game" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})

      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      selected_kana = ["あ", "い", "う", "え", "お", "か", "き", "く"]

      attrs = %{
        "name" => "Kana Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10,
          "require_reading" => false
        }
      }

      {:ok, game} =
        Games.create_kana_memory_card_game(classroom.id, teacher.id, attrs, selected_kana)

      {:ok, _} = Games.publish_game(game.id, teacher.id)

      %{teacher: teacher, student: student, classroom: classroom, game: game}
    end

    test "renders kana game", %{conn: conn, student: student, classroom: classroom, game: game} do
      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      assert html =~ game.name
      assert html =~ "Kana Memory Card Game"
    end

    test "flipping matching kana cards collects them", %{
      conn: conn,
      student: student,
      classroom: classroom,
      game: game
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/games/#{game.id}")

      session = Games.get_user_session(game.id, student.id)
      card_positions = session.cards_state["card_positions"]
      kana = Enum.at(card_positions, 0)

      matching_pos =
        Enum.find_index(Enum.with_index(card_positions), fn {char, idx} ->
          idx != 0 and char == kana
        end)

      view |> element("button[phx-click='flip_card'][phx-value-position='0']") |> render_click()

      html =
        view
        |> element("button[phx-click='flip_card'][phx-value-position='#{matching_pos}']")
        |> render_click()

      assert html =~ "Match!"
    end
  end
end
