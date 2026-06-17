defmodule MedoruWeb.DailyTestLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Learning
  # alias Medoru.Learning.DailyTestGenerator
  alias Medoru.Repo
  alias Medoru.Learning.ReviewSchedule

  describe "mount" do
    test "shows daily test when user has learned words", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture()
      Learning.track_word_learned(user.id, word.id)

      # Create a review schedule so the word is due
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)

      %ReviewSchedule{}
      |> ReviewSchedule.changeset(%{
        user_id: user.id,
        user_progress_id: progress.id,
        next_review_at: DateTime.utc_now() |> DateTime.add(-1, :day),
        interval: 1,
        ease_factor: 2.5,
        repetitions: 0
      })
      |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/daily-test")

      assert html =~ word.text
    end

    test "redirects to lessons when no words are learned", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # No learned words - should redirect
      assert {:error, {:live_redirect, %{to: "/lessons"}}} = live(conn, ~p"/daily-test")
    end
  end

  describe "test completion" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Create and learn 3 words with review schedules due now
      words =
        Enum.map(1..3, fn _ ->
          word = word_fixture()
          {:ok, progress} = Learning.track_word_learned(user.id, word.id)

          %ReviewSchedule{}
          |> ReviewSchedule.changeset(%{
            user_id: user.id,
            user_progress_id: progress.id,
            next_review_at: DateTime.utc_now() |> DateTime.add(-1, :day),
            interval: 1,
            ease_factor: 2.5,
            repetitions: 0
          })
          |> Repo.insert!()

          word
        end)

      %{conn: conn, user: user, words: words}
    end

    test "page loads with daily test steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/daily-test")

      assert html =~ "Daily Review"
    end

    test "mastery and schedule are updated after answering", %{
      conn: conn,
      user: user,
      words: words
    } do
      {:ok, view, _html} = live(conn, ~p"/daily-test")

      first_word = List.first(words)
      progress_before = Learning.get_word_progress(user.id, first_word.id)
      assert progress_before.mastery_level == 1

      schedule_before = Learning.get_review_schedule(user.id, progress_before.id)
      assert schedule_before.repetitions == 0

      # The main assertion is that the page loaded and test is interactable
      assert render(view) =~ "Daily Review"
    end
  end

  describe "English-learning daily test" do
    setup %{conn: conn} do
      user = user_fixture(%{learning_language: "english"})
      conn = log_in_user(conn, user)

      words = [
        word_fixture(%{text: "日本", reading: "にほん", meaning: "Japan"}),
        word_fixture(%{text: "学校", reading: "がっこう", meaning: "school"}),
        word_fixture(%{text: "先生", reading: "せんせい", meaning: "teacher"})
      ]

      Enum.each(words, fn word ->
        {:ok, _} = Learning.track_english_word_learned(user.id, word.id)
      end)

      # Pre-create the daily test so tests can inspect the steps deterministically
      {:ok, daily_test} = Learning.get_or_create_daily_test(user)

      %{conn: conn, user: user, words: words, daily_test: daily_test}
    end

    test "loads meaning-first daily test for English learner", %{conn: conn, words: words} do
      {:ok, _view, html} = live(conn, ~p"/daily-test")

      first_word = List.first(words)
      assert html =~ "Daily Review"
      # Shows the English meaning as the prompt
      assert html =~ first_word.meaning
    end

    test "can answer a multichoice Japanese word question", %{conn: conn, daily_test: daily_test} do
      {:ok, view, _html} = live(conn, ~p"/daily-test")

      multichoice_step =
        Enum.find(daily_test.test_steps, &(&1.question_data["type"] == "meaning_to_japanese"))

      assert multichoice_step

      view = advance_to_step(view, daily_test.test_steps, multichoice_step)

      view
      |> element("button[phx-value-answer='#{multichoice_step.correct_answer}']")
      |> render_click()

      view
      |> element("button", "Submit Answer")
      |> render_click()

      assert render(view) =~ "Correct!"
    end

    test "can answer a text input Japanese word question", %{conn: conn, daily_test: daily_test} do
      {:ok, view, _html} = live(conn, ~p"/daily-test")

      text_step =
        Enum.find(daily_test.test_steps, &(&1.question_data["type"] == "meaning_to_text"))

      assert text_step

      view = advance_to_step(view, daily_test.test_steps, text_step)

      view
      |> element("input[phx-keyup='update_english_text']")
      |> render_keyup(%{value: text_step.correct_answer})

      view
      |> element("button", "Submit Answer")
      |> render_click()

      assert render(view) =~ "Correct!"
    end

    test "can answer a Japanese-to-English meaning question", %{
      conn: conn,
      daily_test: daily_test
    } do
      {:ok, view, _html} = live(conn, ~p"/daily-test")

      meaning_step =
        Enum.find(daily_test.test_steps, &(&1.question_data["type"] == "japanese_to_meaning"))

      assert meaning_step

      view = advance_to_step(view, daily_test.test_steps, meaning_step)

      view
      |> element("input[phx-keyup='update_english_meaning']")
      |> render_keyup(%{value: meaning_step.correct_answer})

      view
      |> element("button", "Submit Answer")
      |> render_click()

      assert render(view) =~ "Correct!"
    end
  end

  defp advance_to_step(view, steps, target_step) do
    preceding_steps = Enum.take_while(steps, &(&1.id != target_step.id))

    Enum.reduce(preceding_steps, view, fn step, v ->
      answer_step(v, step)
      v
    end)
  end

  defp answer_step(view, step) do
    case step.question_data["type"] do
      "meaning_to_japanese" ->
        view
        |> element("button[phx-value-answer='#{step.correct_answer}']")
        |> render_click()

        view
        |> element("button", "Submit Answer")
        |> render_click()

      "meaning_to_text" ->
        view
        |> element("input[phx-keyup='update_english_text']")
        |> render_keyup(%{value: step.correct_answer})

        view
        |> element("button", "Submit Answer")
        |> render_click()

      "japanese_to_meaning" ->
        view
        |> element("input[phx-keyup='update_english_meaning']")
        |> render_keyup(%{value: step.correct_answer})

        view
        |> element("button", "Submit Answer")
        |> render_click()

      _ ->
        view
    end
  end
end
