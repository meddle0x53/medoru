defmodule Medoru.GamesTest do
  use Medoru.DataCase

  alias Medoru.Classrooms
  alias Medoru.Games
  alias Medoru.Games.{Game, MemoryCardSession}

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "list_classroom_games/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})
      {:ok, teacher: teacher, classroom: classroom}
    end

    test "returns all games for a classroom", %{teacher: teacher, classroom: classroom} do
      {:ok, game} = create_memory_card_game(classroom.id, teacher.id)
      [listed_game] = Games.list_classroom_games(classroom.id)
      assert listed_game.id == game.id
    end

    test "filters by status", %{teacher: teacher, classroom: classroom} do
      {:ok, game} = create_memory_card_game(classroom.id, teacher.id)

      assert Games.list_classroom_games(classroom.id, status: :published) == []

      {:ok, _} = Games.publish_game(game.id, teacher.id)
      [listed_game] = Games.list_classroom_games(classroom.id, status: :published)
      assert listed_game.id == game.id
    end
  end

  describe "get_game!/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})
      {:ok, teacher: teacher, classroom: classroom}
    end

    test "returns game with preloaded associations", %{teacher: teacher, classroom: classroom} do
      {:ok, game} = create_memory_card_game(classroom.id, teacher.id)
      fetched = Games.get_game!(game.id)
      assert fetched.id == game.id
      assert fetched.memory_card_game != nil
    end
  end

  describe "create_memory_card_game/4" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})
      words = Enum.map(1..8, fn _ -> word_fixture() end)
      {:ok, teacher: teacher, classroom: classroom, words: words}
    end

    test "creates a memory card game with words", %{teacher: teacher, classroom: classroom, words: words} do
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

      assert {:ok, %Game{} = game} = Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)
      assert game.name == "Test Game"
      assert game.type == "memory_cards"
      assert game.status == :draft
      assert game.memory_card_game.board_size == "4x4"
      assert game.memory_card_game.max_attempts == 10
      assert length(game.memory_card_game.memory_card_game_words) == 8
    end

    test "returns error when teacher does not own classroom", %{classroom: classroom, words: words} do
      other_teacher = user_fixture(%{type: "teacher"})
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      attrs = %{
        "name" => "Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10
        }
      }

      assert {:error, :not_authorized} = Games.create_memory_card_game(classroom.id, other_teacher.id, attrs, word_ids_with_points)
    end
  end

  describe "publish_game/2 and unpublish_game/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})
      words = Enum.map(1..8, fn _ -> word_fixture() end)
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      attrs = %{
        "name" => "Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10
        }
      }

      {:ok, game} = Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)
      {:ok, teacher: teacher, classroom: classroom, game: game}
    end

    test "publishes a game", %{teacher: teacher, game: game} do
      assert {:ok, %Game{status: :published}} = Games.publish_game(game.id, teacher.id)
    end

    test "unpublishes a game", %{teacher: teacher, game: game} do
      {:ok, _} = Games.publish_game(game.id, teacher.id)
      assert {:ok, %Game{status: :draft}} = Games.unpublish_game(game.id, teacher.id)
    end

    test "returns error for unauthorized teacher", %{game: game} do
      other_teacher = user_fixture(%{type: "teacher"})
      assert {:error, :not_authorized} = Games.publish_game(game.id, other_teacher.id)
    end
  end

  describe "delete_game/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})
      words = Enum.map(1..8, fn _ -> word_fixture() end)
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      attrs = %{
        "name" => "Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10
        }
      }

      {:ok, game} = Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)
      {:ok, teacher: teacher, classroom: classroom, game: game}
    end

    test "deletes a game", %{teacher: teacher, game: game} do
      assert {:ok, _} = Games.delete_game(game.id, teacher.id)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(game.id) end
    end

    test "returns error for unauthorized teacher", %{game: game} do
      other_teacher = user_fixture(%{type: "teacher"})
      assert {:error, :not_authorized} = Games.delete_game(game.id, other_teacher.id)
    end
  end

  describe "session management" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})

      # Approve student membership
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      words = Enum.map(1..8, fn _ -> word_fixture() end)
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      attrs = %{
        "name" => "Test Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10
        }
      }

      {:ok, game} = Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)
      {:ok, _} = Games.publish_game(game.id, teacher.id)

      {:ok, teacher: teacher, student: student, classroom: classroom, game: game, words: words}
    end

    test "get_or_create_session creates new session", %{student: student, game: game} do
      assert {:ok, %MemoryCardSession{} = session} = Games.get_or_create_session(game.id, student.id)
      assert session.status == :in_progress
      assert session.score == 0
      assert session.attempts_used == 0
      assert session.max_attempts == 10
      assert map_size(session.cards_state) > 0
    end

    test "get_or_create_session returns existing session", %{student: student, game: game} do
      {:ok, session1} = Games.get_or_create_session(game.id, student.id)
      {:ok, session2} = Games.get_or_create_session(game.id, student.id)
      assert session1.id == session2.id
    end

    test "flip_card flips first card", %{student: student, game: game} do
      {:ok, session} = Games.get_or_create_session(game.id, student.id)
      assert {:ok, updated} = Games.flip_card(session.id, 0)
      assert [0] == (updated.cards_state["flipped_indices"] || [])
    end

    test "flip_card handles no match", %{student: student, game: game} do
      {:ok, session} = Games.get_or_create_session(game.id, student.id)

      # Find two positions with different words
      card_positions = session.cards_state["card_positions"]
      pos0_word = Enum.at(card_positions, 0)
      pos1 = Enum.find_index(Enum.with_index(card_positions), fn {word_id, idx} -> idx != 0 and word_id != pos0_word end) || 1

      # First card
      assert {:ok, session_after_first} = Games.flip_card(session.id, 0)
      # Second card (different word)
      assert {:ok, updated, :no_match} = Games.flip_card(session_after_first.id, pos1)
      assert updated.attempts_used == 1
      # Cards stay flipped for reveal, then close_flipped_cards clears them
      assert updated.cards_state["flipped_indices"] == [0, pos1]

      # Close the flipped cards
      assert {:ok, closed} = Games.close_flipped_cards(updated.id)
      assert closed.cards_state["flipped_indices"] == []
    end

    test "flip_card handles direct collection", %{student: student, game: game} do
      {:ok, session} = Games.get_or_create_session(game.id, student.id)

      # Find two positions with the same word
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)
      matching_pos = Enum.find_index(Enum.drop(card_positions, 1), &(&1 == word_id)) + 1

      # First card
      assert {:ok, session_after_first} = Games.flip_card(session.id, 0)
      # Second card (same word)
      assert {:ok, updated, :collected, points} = Games.flip_card(session_after_first.id, matching_pos)
      assert updated.score == points
      assert 0 in (updated.cards_state["collected_indices"] || [])
      assert matching_pos in (updated.cards_state["collected_indices"] || [])
    end

    test "complete_session adds points to classroom membership", %{student: student, classroom: classroom, game: game} do
      {:ok, session} = Games.get_or_create_session(game.id, student.id)

      # Flip and collect a pair
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)
      matching_pos = Enum.find_index(Enum.drop(card_positions, 1), &(&1 == word_id)) + 1

      assert {:ok, session} = Games.flip_card(session.id, 0)
      assert {:ok, updated, :collected, points} = Games.flip_card(session.id, matching_pos)

      # Complete the session
      assert {:ok, completed} = Games.complete_session(updated.id)
      assert completed.status == :completed

      # Check points were added
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      assert membership.points == points
    end

    test "reset_session removes points and deletes session", %{student: student, classroom: classroom, game: game} do
      {:ok, session} = Games.get_or_create_session(game.id, student.id)

      # Complete a session to earn points
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)
      matching_pos = Enum.find_index(Enum.drop(card_positions, 1), &(&1 == word_id)) + 1

      assert {:ok, session} = Games.flip_card(session.id, 0)
      assert {:ok, updated, :collected, _points} = Games.flip_card(session.id, matching_pos)
      assert {:ok, completed} = Games.complete_session(updated.id)

      earned_points = completed.score
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      assert membership.points == earned_points

      # Reset the session
      assert {:ok, _} = Games.reset_session(game.id, student.id)

      # Points should be removed
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      assert membership.points == 0

      # Session should be deleted
      assert Games.get_user_session(game.id, student.id) == nil
    end
  end

  describe "collection conditions" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      {:ok, classroom} = Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher.id})

      # Approve student membership
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      membership = Classrooms.get_user_membership(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      words = Enum.map(1..8, fn _ -> word_fixture() end)
      word_ids_with_points = Enum.map(words, &{&1.id, 1})

      {:ok, teacher: teacher, student: student, classroom: classroom, words: words, word_ids_with_points: word_ids_with_points}
    end

    test "meaning condition requires correct meaning", %{teacher: teacher, student: student, classroom: classroom, words: words, word_ids_with_points: word_ids_with_points} do
      attrs = %{
        "name" => "Meaning Game",
        "memory_card_game" => %{
          "board_size" => "4x4",
          "max_attempts" => 10,
          "meaning_required_for_collection" => true,
          "pronunciation_required_for_collection" => false,
          "meaning_or_pronunciation_required_for_collection" => false
        }
      }

      {:ok, game} = Games.create_memory_card_game(classroom.id, teacher.id, attrs, word_ids_with_points)
      {:ok, _} = Games.publish_game(game.id, teacher.id)
      {:ok, session} = Games.get_or_create_session(game.id, student.id)

      # Find matching pair
      card_positions = session.cards_state["card_positions"]
      word_id = Enum.at(card_positions, 0)
      matching_pos = Enum.find_index(Enum.drop(card_positions, 1), &(&1 == word_id)) + 1

      # Flip both cards
      assert {:ok, session_after_first} = Games.flip_card(session.id, 0)
      assert {:needs_input, updated, _} = Games.flip_card(session_after_first.id, matching_pos)
      assert updated.cards_state["flipped_indices"] == [0, matching_pos]

      # Submit wrong answer
      assert {:ok, after_wrong, :wrong_answer} = Games.submit_collection_answer(updated.id, %{"meaning" => "wrong", "pronunciation" => ""})
      assert after_wrong.attempts_used == 1

      # Need to re-flip cards after wrong answer
      assert {:ok, after_wrong_first} = Games.flip_card(after_wrong.id, 0)
      assert {:needs_input, after_wrong_both, _} = Games.flip_card(after_wrong_first.id, matching_pos)

      # Submit correct answer
      word = Enum.find(words, fn w ->
        encoded = case Ecto.UUID.dump(w.id) do
          {:ok, _} -> w.id
          :error -> to_string(w.id)
        end
        encoded == word_id
      end)

      assert {:ok, after_correct, :collected, _} = Games.submit_collection_answer(after_wrong_both.id, %{"meaning" => word.meaning, "pronunciation" => ""})
      assert 0 in (after_correct.cards_state["collected_indices"] || [])
    end
  end

  # Helper functions

  defp create_memory_card_game(classroom_id, teacher_id, attrs \\ %{}) do
    words = Enum.map(1..8, fn _ -> word_fixture() end)
    word_ids_with_points = Enum.map(words, &{&1.id, 1})

    default_attrs = %{
      "name" => "Test Game",
      "memory_card_game" => %{
        "board_size" => "4x4",
        "max_attempts" => 10,
        "meaning_required_for_collection" => false,
        "pronunciation_required_for_collection" => false,
        "meaning_or_pronunciation_required_for_collection" => false
      }
    }

    merged_attrs = Map.merge(default_attrs, attrs)
    Games.create_memory_card_game(classroom_id, teacher_id, merged_attrs, word_ids_with_points)
  end
end
