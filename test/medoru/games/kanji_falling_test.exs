defmodule Medoru.Games.KanjiFallingTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.{Classrooms, Games}

  describe "create_kanji_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      # Create test kanji with readings
      _kanji1 = kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :on, reading: "ニチ", romaji: "nichi", usage_notes: ""},
        %{reading_type: :kun, reading: "ひ", romaji: "hi", usage_notes: ""}
      ])

      _kanji2 = kanji_with_readings_fixture(%{character: "月"}, [
        %{reading_type: :on, reading: "ゲツ", romaji: "getsu", usage_notes: ""},
        %{reading_type: :kun, reading: "つき", romaji: "tsuki", usage_notes: ""}
      ])

      _kanji3 = kanji_with_readings_fixture(%{character: "火"}, [
        %{reading_type: :on, reading: "カ", romaji: "ka", usage_notes: ""},
        %{reading_type: :kun, reading: "ひ", romaji: "hi", usage_notes: ""}
      ])

      _kanji4 = kanji_with_readings_fixture(%{character: "水"}, [
        %{reading_type: :on, reading: "スイ", romaji: "sui", usage_notes: ""},
        %{reading_type: :kun, reading: "みず", romaji: "mizu", usage_notes: ""}
      ])

      _kanji5 = kanji_with_readings_fixture(%{character: "木"}, [
        %{reading_type: :on, reading: "モク", romaji: "moku", usage_notes: ""},
        %{reading_type: :kun, reading: "き", romaji: "ki", usage_notes: ""}
      ])

      %{teacher: teacher, classroom: classroom, kanji_chars: ["日", "月", "火", "水", "木"]}
    end

    test "creates a kanji falling game with selected kanji", %{teacher: teacher, classroom: classroom, kanji_chars: chars} do
      attrs = %{
        "name" => "Falling Kanji Test",
        "kanji_falling_game" => %{
          "initial_speed" => "3",
          "speed_increase_threshold" => "50",
          "lives" => "5",
          "extra_life_threshold" => "100",
          "points_per_kanji" => "2",
          "reading_type" => "any",
          "keyboard_type" => "hiragana"
        }
      }

      assert {:ok, game} =
               Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, chars)

      assert game.name == "Falling Kanji Test"
      assert game.type == "kanji_falling"
      assert game.kanji_falling_game.initial_speed == 3
      assert game.kanji_falling_game.lives == 5
      assert game.kanji_falling_game.points_per_kanji == 2
      assert game.kanji_falling_game.selected_kanji == chars
      assert game.kanji_falling_game.reading_type == "any"
      assert game.kanji_falling_game.keyboard_type == "hiragana"
      assert map_size(game.kanji_falling_game.kanji_colors) == 5
    end

    test "rejects unauthorized teacher", %{classroom: classroom} do
      other_teacher = user_fixture()

      assert {:error, :not_authorized} =
               Games.create_kanji_falling_game(
                 classroom.id,
                 other_teacher.id,
                 %{"name" => "Test"},
                 ["日", "月", "火", "水", "木"]
               )
    end

    test "requires at least 1 kanji", %{teacher: teacher, classroom: classroom} do
      attrs = %{
        "name" => "Test",
        "kanji_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:error, changeset} =
               Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, [])

      assert "at least 1 kanji required" in errors_on(changeset).selected_kanji
    end
  end

  describe "update_kanji_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      _kanji1 = kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :on, reading: "ニチ", romaji: "nichi", usage_notes: ""}
      ])

      _kanji2 = kanji_with_readings_fixture(%{character: "月"}, [
        %{reading_type: :on, reading: "ゲツ", romaji: "getsu", usage_notes: ""}
      ])

      _kanji3 = kanji_with_readings_fixture(%{character: "火"}, [
        %{reading_type: :on, reading: "カ", romaji: "ka", usage_notes: ""}
      ])

      _kanji4 = kanji_with_readings_fixture(%{character: "水"}, [
        %{reading_type: :on, reading: "スイ", romaji: "sui", usage_notes: ""}
      ])

      _kanji5 = kanji_with_readings_fixture(%{character: "木"}, [
        %{reading_type: :on, reading: "モク", romaji: "moku", usage_notes: ""}
      ])

      _kanji6 = kanji_with_readings_fixture(%{character: "土"}, [
        %{reading_type: :on, reading: "ド", romaji: "do", usage_notes: ""}
      ])

      attrs = %{
        "name" => "Original Name",
        "kanji_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "reading_type" => "any",
          "keyboard_type" => "hiragana"
        }
      }

      {:ok, game} =
        Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, ["日", "月", "火", "水", "木"])

      %{teacher: teacher, classroom: classroom, game: game, extra_kanji: "土"}
    end

    test "updates game settings", %{teacher: teacher, game: game} do
      attrs = %{
        "name" => "Updated Name",
        "kanji_falling_game" => %{
          "initial_speed" => "5",
          "lives" => "10",
          "reading_type" => "onyomi",
          "keyboard_type" => "latin"
        }
      }

      assert {:ok, updated} =
               Games.update_kanji_falling_game(game, teacher.id, attrs, ["日", "月", "火", "水", "木", "土"])

      assert updated.name == "Updated Name"
      assert updated.kanji_falling_game.initial_speed == 5
      assert updated.kanji_falling_game.lives == 10
      assert updated.kanji_falling_game.reading_type == "onyomi"
      assert updated.kanji_falling_game.keyboard_type == "latin"
      assert updated.kanji_falling_game.selected_kanji == ["日", "月", "火", "水", "木", "土"]
    end

    test "recomputes colors when kanji selection changes", %{teacher: teacher, game: game, extra_kanji: extra} do
      original_colors = game.kanji_falling_game.kanji_colors

      attrs = %{
        "name" => "Updated",
        "kanji_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:ok, updated} =
               Games.update_kanji_falling_game(game, teacher.id, attrs, ["日", "月", "火", "水", "木", extra])

      assert updated.kanji_falling_game.kanji_colors != original_colors
    end

    test "preserves colors when kanji selection unchanged", %{teacher: teacher, game: game} do
      original_colors = game.kanji_falling_game.kanji_colors

      attrs = %{
        "name" => "Updated",
        "kanji_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:ok, updated} =
               Games.update_kanji_falling_game(game, teacher.id, attrs, ["日", "月", "火", "水", "木"])

      assert updated.kanji_falling_game.kanji_colors == original_colors
    end
  end

  describe "kanji falling sessions" do
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

      _kanji = kanji_with_readings_fixture(%{character: "日"}, [
        %{reading_type: :on, reading: "ニチ", romaji: "nichi", usage_notes: ""}
      ])

      attrs = %{
        "name" => "Falling Game",
        "kanji_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      {:ok, game} =
        Games.create_kanji_falling_game(classroom.id, teacher.id, attrs, ["日"])

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

      assert {:ok, session} = Games.create_kanji_falling_session(attrs)
      assert session.score == 150
    end

    test "gets user high score", %{student: student, game: game} do
      assert Games.get_kanji_falling_high_score(game.id, student.id) == 0

      Games.create_kanji_falling_session(%{
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

      assert Games.get_kanji_falling_high_score(game.id, student.id) == 100

      Games.create_kanji_falling_session(%{
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

      assert Games.get_kanji_falling_high_score(game.id, student.id) == 200
    end

    test "lists sessions for rankings", %{student: student, game: game} do
      Games.create_kanji_falling_session(%{
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

      Games.create_kanji_falling_session(%{
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

      sessions = Games.list_kanji_falling_sessions(game.id)
      assert length(sessions) == 1
      assert hd(sessions).score == 200
    end
  end
end
