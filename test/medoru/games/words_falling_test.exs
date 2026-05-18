defmodule Medoru.Games.WordsFallingTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.{Classrooms, Games}

  describe "create_words_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう"})
      word3 = word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい"})
      word4 = word_fixture(%{text: "学生", meaning: "student", reading: "がくせい"})
      word5 = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})

      %{
        teacher: teacher,
        classroom: classroom,
        word_ids: [word1.id, word2.id, word3.id, word4.id, word5.id]
      }
    end

    test "creates a words falling game with selected words", %{
      teacher: teacher,
      classroom: classroom,
      word_ids: word_ids
    } do
      attrs = %{
        "name" => "Falling Words Test",
        "words_falling_game" => %{
          "initial_speed" => "3",
          "speed_increase_threshold" => "50",
          "lives" => "5",
          "extra_life_threshold" => "100",
          "game_mode" => "0",
          "keyboard_type" => "latin"
        }
      }

      assert {:ok, game} =
               Games.create_words_falling_game(classroom.id, teacher.id, attrs, word_ids)

      assert game.name == "Falling Words Test"
      assert game.type == "words_falling"
      assert game.words_falling_game.initial_speed == 3
      assert game.words_falling_game.lives == 5
      assert game.words_falling_game.game_mode == 0
      assert game.words_falling_game.keyboard_type == "latin"
      assert length(game.words_falling_game.selected_words) == 5
      assert map_size(game.words_falling_game.word_colors) == 5
    end

    test "rejects unauthorized teacher", %{classroom: classroom} do
      other_teacher = user_fixture()

      word = word_fixture()

      assert {:error, :not_authorized} =
               Games.create_words_falling_game(
                 classroom.id,
                 other_teacher.id,
                 %{"name" => "Test"},
                 [word.id]
               )
    end

    test "requires at least 1 word", %{teacher: teacher, classroom: classroom} do
      attrs = %{
        "name" => "Test",
        "words_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:error, changeset} =
               Games.create_words_falling_game(classroom.id, teacher.id, attrs, [])

      assert "at least 1 word required" in errors_on(changeset).selected_words
    end
  end

  describe "update_words_falling_game/4" do
    setup do
      teacher = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "学校", meaning: "school", reading: "がっこう"})
      word3 = word_fixture(%{text: "先生", meaning: "teacher", reading: "せんせい"})
      word4 = word_fixture(%{text: "学生", meaning: "student", reading: "がくせい"})
      word5 = word_fixture(%{text: "本", meaning: "book", reading: "ほん"})
      word6 = word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"})

      attrs = %{
        "name" => "Original Name",
        "words_falling_game" => %{
          "initial_speed" => "1",
          "lives" => "3",
          "game_mode" => "0",
          "keyboard_type" => "latin"
        }
      }

      {:ok, game} =
        Games.create_words_falling_game(classroom.id, teacher.id, attrs, [
          word1.id,
          word2.id,
          word3.id,
          word4.id,
          word5.id
        ])

      %{teacher: teacher, classroom: classroom, game: game, extra_word: word6}
    end

    test "updates game settings", %{teacher: teacher, game: game, extra_word: extra_word} do
      attrs = %{
        "name" => "Updated Name",
        "words_falling_game" => %{
          "initial_speed" => "5",
          "lives" => "10",
          "game_mode" => "1",
          "keyboard_type" => "hiragana"
        }
      }

      assert {:ok, updated} =
               Games.update_words_falling_game(game, teacher.id, attrs, [
                 hd(game.words_falling_game.selected_words),
                 extra_word.id
               ])

      assert updated.name == "Updated Name"
      assert updated.words_falling_game.initial_speed == 5
      assert updated.words_falling_game.lives == 10
      assert updated.words_falling_game.game_mode == 1
      assert updated.words_falling_game.keyboard_type == "hiragana"
    end

    test "recomputes colors when word selection changes", %{
      teacher: teacher,
      game: game,
      extra_word: extra
    } do
      original_colors = game.words_falling_game.word_colors

      attrs = %{
        "name" => "Updated",
        "words_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:ok, updated} =
               Games.update_words_falling_game(game, teacher.id, attrs, [
                 hd(game.words_falling_game.selected_words),
                 extra.id
               ])

      assert updated.words_falling_game.word_colors != original_colors
    end

    test "preserves colors when word selection unchanged", %{teacher: teacher, game: game} do
      original_colors = game.words_falling_game.word_colors

      attrs = %{
        "name" => "Updated",
        "words_falling_game" => %{"initial_speed" => "1", "lives" => "3"}
      }

      assert {:ok, updated} =
               Games.update_words_falling_game(
                 game,
                 teacher.id,
                 attrs,
                 game.words_falling_game.selected_words
               )

      assert updated.words_falling_game.word_colors == original_colors
    end
  end

  describe "words falling sessions" do
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

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      attrs = %{
        "name" => "Falling Game",
        "words_falling_game" => %{"initial_speed" => "1", "lives" => "3", "game_mode" => "0"}
      }

      {:ok, game} =
        Games.create_words_falling_game(classroom.id, teacher.id, attrs, [word.id])

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

      assert {:ok, session} = Games.create_words_falling_session(attrs)
      assert session.score == 150
    end

    test "gets user high score", %{student: student, game: game} do
      assert Games.get_words_falling_high_score(game.id, student.id) == 0

      Games.create_words_falling_session(%{
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

      assert Games.get_words_falling_high_score(game.id, student.id) == 100

      Games.create_words_falling_session(%{
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

      assert Games.get_words_falling_high_score(game.id, student.id) == 200
    end

    test "lists sessions for rankings", %{student: student, game: game} do
      Games.create_words_falling_session(%{
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

      Games.create_words_falling_session(%{
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

      sessions = Games.list_words_falling_sessions(game.id)
      assert length(sessions) == 1
      assert hd(sessions).score == 200
    end
  end
end
