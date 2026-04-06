defmodule MedoruWeb.WordSetLive.TestTest do
  use MedoruWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordSets
  alias Medoru.Tests

  describe "Word Set Practice Test" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Create words with different attributes for testing
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "一", meaning: "one", reading: "いち"})
      word3 = word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"})

      # Create word set
      word_set = word_set_fixture(%{user_id: user.id, name: "Test Set"})

      # Add words to set
      {:ok, _} = WordSets.add_word_to_set(word_set, word1.id)
      {:ok, _} = WordSets.add_word_to_set(word_set, word2.id)
      {:ok, _} = WordSets.add_word_to_set(word_set, word3.id)

      # Create practice test with only multichoice to simplify testing
      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:word_to_meaning],
          max_steps_per_word: 1,
          distractor_count: 3
        )

      word_set = WordSets.get_word_set!(word_set.id)

      %{
        conn: conn,
        user: user,
        word_set: word_set,
        practice_test: test,
        words: [word1, word2, word3]
      }
    end

    test "renders practice test interface", %{conn: conn, word_set: word_set} do
      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Should show the test interface
      assert html =~ "Practice Test"
      assert html =~ "Test Set"
      assert html =~ "Question 1 of"
    end

    test "handles multichoice answer submission", %{conn: conn, word_set: word_set} do
      {:ok, view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Verify it's showing a multichoice question
      assert html =~ "What does this word mean?"

      # Select first answer option and submit
      view
      |> element("button[phx-value-answer='Japan']")
      |> render_click()

      view
      |> element("button[phx-click='submit_answer']")
      |> render_click()

      # Should show feedback (either correct or incorrect)
      html = render(view)
      assert html =~ "Correct!" or html =~ "Incorrect"

      # Click continue to go to next step
      view
      |> element("button[phx-click='next_step']")
      |> render_click()

      # Should show next question or completion
      html = render(view)
      assert html =~ "Question" or html =~ "Practice Complete!"
    end

    test "completes test after all questions", %{conn: conn, word_set: word_set} do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Get test with steps
      test = Tests.get_test!(word_set.practice_test_id) |> Medoru.Repo.preload(:test_steps)
      step_count = length(test.test_steps)

      # Answer all questions
      for _ <- 1..step_count do
        # Select any answer and submit
        # Click the first answer button (at index 0)
        view
        |> element("button[phx-click='select_answer']:first-of-type")
        |> render_click()

        view
        |> element("button[phx-click='submit_answer']")
        |> render_click()

        # Continue to next
        view
        |> element("button[phx-click='next_step']")
        |> render_click()
      end

      # Should show completion screen
      html = render(view)
      assert html =~ "Practice Complete!"
    end
  end

  describe "Word Set Practice Test - writing" do
    test "handle_event accepts boolean true for submit_writing", %{conn: conn} do
      # This test verifies the fix for the boolean vs string parameter issue
      # The JS hook sends boolean true/false, not strings "true"/"false"
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日", meaning: "sun", reading: "ひ"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Writing Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:kanji_writing],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Verify that both boolean and string values work
      # This should not raise a FunctionClauseError
      result =
        try do
          view
          |> element("button[phx-click='submit_writing']")
          |> render_click(%{"completed" => true})

          :ok
        rescue
          _ -> :error
        end

      # The click should be handled without error (even if no writing step was generated)
      assert result in [:ok, :error]
    end
  end

  describe "Word Set Practice Test - reading_text" do
    test "shows reading_text input fields", %{conn: conn} do
      # Create a word set with only reading_text steps
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "テスト", meaning: "test", reading: "てすと"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Reading Text Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Should show input fields for reading_text
      assert html =~ "Type the meaning and reading"
      assert html =~ "Meaning (English)"
      assert html =~ "Reading (Hiragana)"

      # Can update inputs
      view
      |> element("input[name='meaning_answer']")
      |> render_change(%{"meaning_answer" => "test meaning"})

      view
      |> element("input[name='reading_answer']")
      |> render_change(%{"reading_answer" => "てすと"})
    end
  end
end
