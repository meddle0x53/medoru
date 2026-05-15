defmodule Medoru.Games.KanaFallingTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures

  alias Medoru.{Classrooms, Games}

  describe "create_kana_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      %{teacher: teacher, classroom: classroom}
    end

    test "creates a kana falling game with selected kana", %{
      teacher: teacher,
      classroom: classroom
    } do
      attrs = %{
        "name" => "Falling Kana Test",
        "kana_falling_game" => %{
          "initial_speed" => "3",
          "speed_increase_threshold" => "50",
          "lives" => "5",
          "extra_life_threshold" => "100",
          "points_per_kana" => "2"
        }
      }

      selected_kana = ["あ", "い", "う"]

      assert {:ok, game} =
               Games.create_kana_falling_game(classroom.id, teacher.id, attrs, selected_kana)

      assert game.name == "Falling Kana Test"
      assert game.type == "kana_falling"
      assert game.kana_falling_game.initial_speed == 3
      assert game.kana_falling_game.lives == 5
      assert game.kana_falling_game.points_per_kana == 2
      assert game.kana_falling_game.selected_kana == selected_kana
    end

    test "rejects unauthorized teacher", %{classroom: classroom} do
      other_teacher = user_fixture()

      assert {:error, :not_authorized} =
               Games.create_kana_falling_game(
                 classroom.id,
                 other_teacher.id,
                 %{"name" => "Test"},
                 ["あ"]
               )
    end
  end

  describe "update_kana_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      attrs = %{
        "name" => "Original Name",
        "kana_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3"
        }
      }

      {:ok, game} =
        Games.create_kana_falling_game(classroom.id, teacher.id, attrs, ["あ", "い"])

      %{teacher: teacher, classroom: classroom, game: game}
    end

    test "updates game settings", %{teacher: teacher, game: game} do
      attrs = %{
        "name" => "Updated Name",
        "kana_falling_game" => %{
          "initial_speed" => "5",
          "lives" => "10"
        }
      }

      assert {:ok, updated} =
               Games.update_kana_falling_game(game, teacher.id, attrs, ["あ", "い", "う"])

      assert updated.name == "Updated Name"
      assert updated.kana_falling_game.initial_speed == 5
      assert updated.kana_falling_game.lives == 10
      assert updated.kana_falling_game.selected_kana == ["あ", "い", "う"]
    end
  end

  describe "kana falling sessions" do
    setup do
      teacher = user_fixture()
      student = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      Classrooms.apply_to_join(classroom.id, student.id)

      attrs = %{
        "name" => "Falling Game",
        "kana_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      {:ok, game} =
        Games.create_kana_falling_game(classroom.id, teacher.id, attrs, ["あ"])

      %{student: student, game: game}
    end

    test "creates a completed session", %{student: student, game: game} do
      attrs = %{
        game_id: game.id,
        user_id: student.id,
        status: "completed",
        score: 150,
        highest_speed_reached: 4,
        lives_remaining: 0,
        lives_used: 3,
        highest_row_reached: 15,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      }

      assert {:ok, session} = Games.create_kana_falling_session(attrs)
      assert session.score == 150
    end

    test "gets user high score", %{student: student, game: game} do
      assert Games.get_kana_falling_high_score(game.id, student.id) == 0

      # Create session with score 100
      Games.create_kana_falling_session(%{
        game_id: game.id,
        user_id: student.id,
        status: "completed",
        score: 100,
        highest_speed_reached: 3,
        lives_remaining: 0,
        lives_used: 3,
        highest_row_reached: 10,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      })

      assert Games.get_kana_falling_high_score(game.id, student.id) == 100

      # Create session with score 200
      Games.create_kana_falling_session(%{
        game_id: game.id,
        user_id: student.id,
        status: "completed",
        score: 200,
        highest_speed_reached: 5,
        lives_remaining: 0,
        lives_used: 3,
        highest_row_reached: 12,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      })

      assert Games.get_kana_falling_high_score(game.id, student.id) == 200
    end

    test "lists sessions for rankings", %{student: student, game: game} do
      # Create two sessions for the same user - only best should appear
      Games.create_kana_falling_session(%{
        game_id: game.id,
        user_id: student.id,
        status: "completed",
        score: 50,
        highest_speed_reached: 2,
        lives_remaining: 0,
        lives_used: 3,
        highest_row_reached: 8,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      })

      Games.create_kana_falling_session(%{
        game_id: game.id,
        user_id: student.id,
        status: "completed",
        score: 200,
        highest_speed_reached: 5,
        lives_remaining: 0,
        lives_used: 3,
        highest_row_reached: 12,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      })

      sessions = Games.list_kana_falling_sessions(game.id)
      assert length(sessions) == 1
      assert hd(sessions).score == 200
    end
  end
end
