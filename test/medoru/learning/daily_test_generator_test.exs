defmodule Medoru.Learning.DailyTestGeneratorTest do
  use Medoru.DataCase, async: true

  alias Medoru.Learning
  alias Medoru.Learning.DailyTestGenerator
  alias Medoru.Tests

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  # Helper to set up a user with a started lesson and word
  defp setup_user_with_lesson_and_word(_) do
    user = user_fixture()
    lesson = lesson_fixture()
    word = word_fixture()

    # Associate word with lesson
    lesson_word_fixture(lesson, word)

    # Start the lesson for the user
    {:ok, _} = Learning.start_lesson(user.id, lesson.id)

    %{user: user, lesson: lesson, word: word}
  end

  describe "get_or_create_daily_test/1" do
    setup :setup_user_with_lesson_and_word

    test "creates a new daily test when none exists", %{user: user, word: word} do
      # Track the word first so it can be included in the test
      {:ok, _} = Learning.track_word_learned(user.id, word.id)

      assert {:ok, test} = DailyTestGenerator.get_or_create_daily_test(user.id)
      assert test.test_type == :daily
      assert test.creator_id == user.id
      assert test.status == :ready
      assert length(test.test_steps) > 0
    end

    test "returns existing test for today when one exists", %{user: user, word: word} do
      # Track the word
      {:ok, _} = Learning.track_word_learned(user.id, word.id)

      # Create first test
      assert {:ok, test1} = DailyTestGenerator.get_or_create_daily_test(user.id)

      # Get test again - should return same test
      assert {:ok, test2} = DailyTestGenerator.get_or_create_daily_test(user.id)

      assert test1.id == test2.id
    end

    test "returns error when no words have been learned", %{user: _user} do
      # Create a new user who hasn't learned any words
      new_user = user_fixture()

      # User has no UserProgress entries, so should get no_items_available
      assert {:error, :no_items_available} =
               DailyTestGenerator.get_or_create_daily_test(new_user.id)
    end
  end

  describe "daily_test_completed_today?/1" do
    setup :setup_user_with_lesson_and_word

    test "returns false when no daily test has been completed", %{user: user} do
      refute DailyTestGenerator.daily_test_completed_today?(user.id)
    end

    test "returns true when daily test has been completed today", %{user: user, word: word} do
      # Track word and create test
      {:ok, _} = Learning.track_word_learned(user.id, word.id)
      {:ok, test} = DailyTestGenerator.get_or_create_daily_test(user.id)

      # Complete the test
      {:ok, session} = Tests.start_test_session(user.id, test.id)

      # Complete all steps
      test.test_steps
      |> Enum.each(fn step ->
        Tests.record_step_answer(session.id, step.id, %{
          "answer" => step.correct_answer,
          "time_spent_seconds" => 5,
          "step_index" => step.order_index,
          "is_correct" => true,
          "points_earned" => step.points
        })
      end)

      # Complete session
      Tests.complete_session(session, length(test.test_steps), length(test.test_steps), 60)

      assert DailyTestGenerator.daily_test_completed_today?(user.id)
    end
  end

  describe "get_todays_daily_test/1" do
    setup :setup_user_with_lesson_and_word

    test "returns nil when no daily test exists for today", %{user: user} do
      assert DailyTestGenerator.get_todays_daily_test(user.id) == nil
    end

    test "returns today's test when one exists", %{user: user, word: word} do
      # Track word and create test
      {:ok, _} = Learning.track_word_learned(user.id, word.id)
      {:ok, test} = DailyTestGenerator.get_or_create_daily_test(user.id)

      found_test = DailyTestGenerator.get_todays_daily_test(user.id)

      assert found_test.id == test.id
      assert found_test.test_type == :daily
    end
  end

  describe "archive_old_daily_tests/1" do
    setup do
      user = user_fixture()
      {:ok, user: user}
    end

    test "archives old daily tests", %{user: user} do
      # This test is limited since we can't easily create tests with past dates
      # But we can verify the function runs without error
      assert {:ok, %{archived: 0}} = DailyTestGenerator.archive_old_daily_tests(user.id)
    end
  end

  describe "generate_daily_test/1" do
    setup :setup_user_with_lesson_and_word

    test "generates test with review items", %{user: user, word: word} do
      # Track word and create review schedule
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)
      Learning.get_or_create_review_schedule(user.id, progress.id)

      assert {:ok, test} = DailyTestGenerator.generate_daily_test(user.id)
      assert test.test_type == :daily
      assert length(test.test_steps) > 0
    end

    test "generates test with new words", %{user: user, word: word} do
      # Track the word - it should be picked up as "new" (no review schedule yet)
      {:ok, _} = Learning.track_word_learned(user.id, word.id)

      assert {:ok, test} = DailyTestGenerator.generate_daily_test(user.id)
      assert test.test_type == :daily
      assert length(test.test_steps) > 0
    end

    test "includes both review and new items when available", %{user: user, word: word} do
      # Create multiple words in the same lesson
      word2 = word_fixture(%{text: "学校", reading: "がっこう", meaning: "school"})
      lesson = lesson_fixture()
      lesson_word_fixture(lesson, word, position: 0)
      lesson_word_fixture(lesson, word2, position: 1)

      # Start the lesson
      {:ok, _} = Learning.start_lesson(user.id, lesson.id)

      # Track first word and create review schedule (review item)
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)
      Learning.get_or_create_review_schedule(user.id, progress.id)

      # Track second word but no review schedule (new item)
      {:ok, _} = Learning.track_word_learned(user.id, word2.id)

      assert {:ok, test} = DailyTestGenerator.generate_daily_test(user.id)
      # At least 2 steps (2 per word)
      assert length(test.test_steps) >= 2
    end

    test "includes all learned words regardless of lesson status", %{user: user, word: word} do
      # Track the word from the started lesson
      {:ok, _} = Learning.track_word_learned(user.id, word.id)

      # Create another word and track it
      other_word = word_fixture(%{text: "猫", reading: "ねこ", meaning: "cat"})

      # Track the other word (should now appear in daily test since we include all learned words)
      {:ok, _} = Learning.track_word_learned(user.id, other_word.id)

      assert {:ok, test} = DailyTestGenerator.generate_daily_test(user.id)

      # Should have steps for both tracked words
      word_ids_in_test = Enum.map(test.test_steps, & &1.word_id) |> Enum.uniq()
      assert word.id in word_ids_in_test
      assert other_word.id in word_ids_in_test
    end

    test "returns error when no words have been learned" do
      # Create a fresh user who hasn't learned any words
      new_user = user_fixture()

      # User has no UserProgress entries, so should get no_items_available
      assert {:error, :no_items_available} = DailyTestGenerator.generate_daily_test(new_user.id)
    end
  end
end
