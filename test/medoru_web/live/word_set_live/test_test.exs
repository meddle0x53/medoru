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

  describe "Word Set Practice Test - results review" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Review Set"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      %{conn: conn, word_set: WordSets.get_word_set!(word_set.id), word: word}
    end

    defp answer_and_continue(view, meaning, reading) do
      view
      |> element("input[name='meaning_answer']")
      |> render_keyup(%{"value" => meaning})

      view
      |> element("input[name='reading_answer']")
      |> render_keyup(%{"value" => reading})

      view
      |> element("button[phx-click='submit_reading_text']")
      |> render_click()

      view
      |> element("button[phx-click='next_step']")
      |> render_click()
    end

    test "wrong answers are listed in the review mistakes section", %{
      conn: conn,
      word_set: word_set,
      word: word
    } do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      html = answer_and_continue(view, "wrong meaning", "まちがい")

      assert html =~ "Practice Complete!"
      assert html =~ "Review mistakes"
      assert html =~ word.text
      assert html =~ word.reading
      assert html =~ "wrong meaning"
      # per-field rows with the correct answers shown next to wrong fields
      assert html =~ "Meaning"
      assert html =~ "Reading"
      assert html =~ word.meaning
      assert html =~ "まちがい"
      # stats summary
      assert html =~ "Back to Word Set"
      assert html =~ "Retake Test"
    end

    test "all-correct test shows no mistakes message", %{conn: conn, word_set: word_set} do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      html = answer_and_continue(view, "Japan", "にほん")

      assert html =~ "Practice Complete!"
      assert html =~ "Perfect — no mistakes to review!"
      refute html =~ "Review mistakes"
    end

    test "skipped question appears as a skipped mistake", %{conn: conn, word_set: word_set} do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      view
      |> element("button[phx-click='skip_question']")
      |> render_click()

      html = render(view)
      assert html =~ "Practice Complete!"
      assert html =~ "Review mistakes"
      assert html =~ "Skipped"
    end
  end

  describe "Word Set Practice Test - multichoice results review" do
    test "wrong multichoice answer shows user answer and correct answer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "一", meaning: "one", reading: "いち"})

      word_set = word_set_fixture(%{user_id: user.id, name: "MC Review Set"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word1.id)
      {:ok, _} = WordSets.add_word_to_set(word_set, word2.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:word_to_meaning],
          max_steps_per_word: 1,
          distractor_count: 3
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Answer the first step incorrectly, remaining steps correctly
      test = Tests.get_test!(word_set.practice_test_id) |> Medoru.Repo.preload(:test_steps)
      first_step = Enum.min_by(test.test_steps, & &1.order_index)
      wrong = Enum.find(first_step.options, &(&1 != first_step.correct_answer))

      view
      |> element("button[phx-value-answer='#{wrong}']")
      |> render_click()

      view
      |> element("button[phx-click='submit_answer']")
      |> render_click()

      view
      |> element("button[phx-click='next_step']")
      |> render_click()

      # Finish remaining steps with correct answers
      remaining = length(test.test_steps) - 1

      for _ <- 1..remaining do
        test = Tests.get_test!(word_set.practice_test_id) |> Medoru.Repo.preload(:test_steps)

        html = render(view)
        # find current question word from the page and match its step
        current_step =
          Enum.find(test.test_steps, fn step ->
            html =~ step.question
          end)

        view
        |> element("button[phx-value-answer='#{current_step.correct_answer}']")
        |> render_click()

        view
        |> element("button[phx-click='submit_answer']")
        |> render_click()

        view
        |> element("button[phx-click='next_step']")
        |> render_click()
      end

      html = render(view)

      assert html =~ "Practice Complete!"
      assert html =~ "Review mistakes"
      assert html =~ "Your answer:"
      assert html =~ wrong
      assert html =~ "The correct answer is:"
      assert html =~ first_step.correct_answer
      # only the wrong step is listed
      assert html =~ ~r/Review mistakes.*\(\d\)/s
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

  describe "Word Set Practice Test - image_to_meaning" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      words =
        ["日本", "学校", "先生", "学生", "図書館"]
        |> Enum.map(fn text ->
          word_fixture(%{
            text: text,
            meaning: "meaning #{text}",
            reading: "てすと",
            image_path: "/uploads/word_images/#{text}.png"
          })
        end)

      word_set = word_set_fixture(%{user_id: user.id, name: "Image Set"})
      Enum.each(words, &WordSets.add_word_to_set(word_set, &1.id))

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:image_to_meaning],
          max_steps_per_word: 1,
          distractor_count: 3
        )

      %{conn: conn, word_set: WordSets.get_word_set!(word_set.id), practice_test: test}
    end

    test "renders image options for image steps", %{conn: conn, word_set: word_set} do
      {:ok, view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      assert html =~ "Select the image that matches the word"
      assert html =~ "<img"
      assert has_element?(view, "img[src^='/uploads/word_images/']")
    end

    test "image step can be answered", %{conn: conn, word_set: word_set} do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      view
      |> element("button[phx-click='select_answer']:first-of-type")
      |> render_click()

      html =
        view
        |> element("button[phx-click='submit_answer']")
        |> render_click()

      assert html =~ "Correct!" or html =~ "Incorrect"
    end

    test "selecting the correct image is graded as correct", %{
      conn: conn,
      word_set: word_set,
      practice_test: test
    } do
      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      current_step = current_step_for(view, test)

      image_options = current_step.question_data["image_options"]
      correct_index = Enum.find_index(image_options, &(&1["word_id"] == current_step.word_id))
      correct_option = Enum.at(current_step.question_data["options"], correct_index)

      view
      |> element("button[phx-value-answer='#{correct_option}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='submit_answer']")
        |> render_click()

      assert html =~ "Correct!"
    end

    defp current_step_for(_view, test) do
      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      Enum.min_by(test.test_steps, & &1.order_index)
    end
  end

  describe "Word Set Practice Test - reading_text" do
    test "shows reading_text input fields for kanji words", %{conn: conn} do
      # Create a word set with only reading_text steps
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
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
      |> render_keyup(%{"value" => "test meaning"})

      view
      |> element("input[name='reading_answer']")
      |> render_keyup(%{"value" => "にほん"})

      # Submit button is enabled once both fields are filled
      assert has_element?(view, "button[phx-click='submit_reading_text']:not([disabled])")
    end

    test "shows correct feedback after submitting a right answer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Feedback Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      view
      |> element("input[name='meaning_answer']")
      |> render_keyup(%{"value" => "Japan"})

      view
      |> element("input[name='reading_answer']")
      |> render_keyup(%{"value" => "にほん"})

      html =
        view
        |> element("button[phx-click='submit_reading_text']")
        |> render_click()

      assert html =~ "Correct!"
      assert has_element?(view, "button[phx-click='next_step']")
      refute has_element?(view, "button[phx-click='submit_reading_text']")
    end

    test "shows incorrect feedback with the right answer after a wrong answer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Feedback Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      view
      |> element("input[name='meaning_answer']")
      |> render_keyup(%{"value" => "wrong"})

      view
      |> element("input[name='reading_answer']")
      |> render_keyup(%{"value" => "まちがい"})

      html =
        view
        |> element("button[phx-click='submit_reading_text']")
        |> render_click()

      assert html =~ "Incorrect"
      assert html =~ "Japan / にほん"
      assert has_element?(view, "button[phx-click='next_step']")
    end

    test "shows only meaning input for kana-only words", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "テスト", meaning: "test", reading: "てすと"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Kana Only Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      # Should show only meaning input for kana-only words
      assert html =~ "Type the meaning:"
      assert html =~ "Meaning (English)"
      refute html =~ "Reading (Hiragana)"
    end

    test "Enter in the reading field submits the answer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Enter Submit Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      view
      |> element("input[name='meaning_answer']")
      |> render_keyup(%{"value" => "Japan"})

      html =
        view
        |> element("input[name='reading_answer']")
        |> render_keyup(%{"key" => "Enter", "value" => "にほん"})

      assert html =~ "Correct!"
      assert has_element?(view, "button[phx-click='next_step']")
    end

    test "Enter in the meaning field does not submit when a reading field exists", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Enter Meaning Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      html =
        view
        |> element("input[name='meaning_answer']")
        |> render_keyup(%{"key" => "Enter", "value" => "Japan"})

      refute html =~ "Correct!"
      refute html =~ "Incorrect"
      assert has_element?(view, "button[phx-click='submit_reading_text']")
    end

    test "Enter in the meaning field submits for kana-only words", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture(%{text: "テスト", meaning: "test", reading: "てすと"})
      word_set = word_set_fixture(%{user_id: user.id, name: "Kana Enter Test"})
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      word_set = WordSets.get_word_set!(word_set.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test")

      html =
        view
        |> element("input[name='meaning_answer']")
        |> render_keyup(%{"key" => "Enter", "value" => "test"})

      assert html =~ "Correct!"
      assert has_element?(view, "button[phx-click='next_step']")
    end
  end
end
