defmodule MedoruWeb.LearnLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "Learn page" do
    setup do
      lesson = lesson_with_words_fixture()
      %{lesson: lesson}
    end

    test "renders learn interface for anonymous user", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      assert html =~ "Word 1 of"
      assert html =~ lesson.title
      assert html =~ List.first(lesson.lesson_words).word.text
    end

    test "renders learn interface for authenticated user", %{conn: conn, lesson: lesson} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      assert html =~ "Word 1 of"
      assert html =~ lesson.title
      assert html =~ "Mark Learned"
    end

    test "creates lesson progress when starting lesson", %{conn: conn, lesson: lesson} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Verify lesson was started
      assert Medoru.Learning.lesson_started?(user.id, lesson.id)
    end

    test "navigating next shows next word", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      first_word = List.first(lesson.lesson_words).word
      second_word = Enum.at(lesson.lesson_words, 1).word

      assert render(view) =~ first_word.text

      view
      |> element("button", "Next")
      |> render_click()

      assert render(view) =~ second_word.text
    end

    test "navigating previous shows previous word", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      first_word = List.first(lesson.lesson_words).word
      second_word = Enum.at(lesson.lesson_words, 1).word

      # Move to next word first
      view
      |> element("button", "Next")
      |> render_click()

      assert render(view) =~ second_word.text

      # Go back
      view
      |> element("button", "Previous")
      |> render_click()

      assert render(view) =~ first_word.text
    end

    test "previous button is disabled on first word", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      assert view
             |> element("button[disabled]", "Previous")
             |> has_element?()
    end

    test "shows completion screen after last word", %{conn: conn, lesson: lesson} do
      word_count = length(lesson.lesson_words)

      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Navigate through all words
      for _ <- 1..(word_count - 1) do
        view
        |> element("button", "Next")
        |> render_click()
      end

      # Click finish on the last word (use more specific selector to avoid matching "Finish Early")
      view
      |> element("button[class*='bg-primary']", "Finish")
      |> render_click()

      assert render(view) =~ "Lesson Complete!"
    end

    test "completing lesson sets progress to 100%", %{conn: conn, lesson: lesson} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Click finish early
      view
      |> element("button", "Finish Early")
      |> render_click()

      assert render(view) =~ "Lesson Complete!"

      # Verify lesson progress is 100% in database
      progress = Medoru.Learning.get_lesson_progress(user.id, lesson.id)
      assert progress.status == :completed
      assert progress.progress_percentage == 100
    end

    test "marking word as learned tracks progress", %{conn: conn, lesson: lesson} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      word = List.first(lesson.lesson_words).word

      # Mark as learned
      view
      |> element("button", "Mark Learned")
      |> render_click()

      # Wait for auto-advance
      :timer.sleep(600)

      # Verify word is tracked as learned
      assert Medoru.Learning.word_learned?(user.id, word.id)
    end

    test "finish early button navigates to completion", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      view
      |> element("button", "Finish Early")
      |> render_click()

      assert render(view) =~ "Lesson Complete!"
    end

    test "returning to lesson page from completion", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Finish lesson
      view
      |> element("button", "Finish Early")
      |> render_click()

      assert render(view) =~ "Lesson Complete!"

      # Click back to lesson
      {:ok, _view, _html} =
        view
        |> element("button[class*='bg-primary']", "Back to Lesson")
        |> render_click()
        |> follow_redirect(conn, ~p"/lessons/#{lesson.id}")
    end

    test "shows progress bar", %{conn: conn, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Check for progress bar elements (CSS classes or structure)
      html = render(view)
      assert html =~ "bg-base-200"
      assert html =~ "bg-primary"
    end

    test "progress bar updates when navigating", %{conn: conn, lesson: lesson} do
      {:ok, view, html} = live(conn, ~p"/lessons/#{lesson.id}/learn")

      # Initial progress should be 0%
      assert html =~ "width: 0%"

      # Navigate next
      html =
        view
        |> element("button", "Next")
        |> render_click()

      # Progress should have increased
      refute html =~ "width: 0%"
    end

    test "displays kanji breakdown for word", %{conn: conn, lesson: _lesson} do
      # Create a lesson with words that have kanji
      kanji1 = kanji_with_readings_fixture()
      kanji2 = kanji_with_readings_fixture()

      reading1 = List.first(kanji1.kanji_readings)
      reading2 = List.first(kanji2.kanji_readings)

      word =
        word_fixture(%{
          text: kanji1.character <> kanji2.character,
          meaning: "test word"
        })

      Medoru.Content.create_word_kanji(%{
        word_id: word.id,
        kanji_id: kanji1.id,
        kanji_reading_id: reading1.id,
        position: 0
      })

      Medoru.Content.create_word_kanji(%{
        word_id: word.id,
        kanji_id: kanji2.id,
        kanji_reading_id: reading2.id,
        position: 1
      })

      lesson_with_kanji =
        lesson_fixture(%{
          title: "Kanji Lesson",
          difficulty: 5,
          order_index: System.unique_integer([:positive])
        })

      Medoru.Content.create_lesson_word(%{
        lesson_id: lesson_with_kanji.id,
        word_id: word.id,
        position: 0
      })

      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson_with_kanji.id}/learn")

      assert html =~ "Kanji Breakdown"
      assert html =~ kanji1.character
      assert html =~ kanji2.character
    end

    test "links to kanji detail page", %{conn: conn, lesson: _lesson} do
      # Create lesson with kanji-containing word
      kanji = kanji_with_readings_fixture()
      reading = List.first(kanji.kanji_readings)

      word =
        word_fixture(%{
          text: kanji.character,
          meaning: "test word"
        })

      Medoru.Content.create_word_kanji(%{
        word_id: word.id,
        kanji_id: kanji.id,
        kanji_reading_id: reading.id,
        position: 0
      })

      lesson_with_kanji =
        lesson_fixture(%{
          title: "Kanji Lesson",
          difficulty: 5,
          order_index: System.unique_integer([:positive])
        })

      Medoru.Content.create_lesson_word(%{
        lesson_id: lesson_with_kanji.id,
        word_id: word.id,
        position: 0
      })

      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson_with_kanji.id}/learn")

      assert view
             |> element("a[href=\"/kanji/#{kanji.id}\"]")
             |> has_element?()
    end
  end

  describe "Learn page errors" do
    test "returns error for non-existent lesson", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/lessons/#{non_existent_id}/learn")
      end
    end
  end
end
