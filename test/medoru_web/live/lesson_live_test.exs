defmodule MedoruWeb.LessonLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  describe "Index" do
    setup [:create_lesson, :create_user]

    test "lists all lessons", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "Lessons"
      assert html =~ lesson.title
      assert html =~ "Learn vocabulary through structured lessons"
    end

    test "filters lessons by difficulty", %{conn: conn} do
      _n5_lesson = lesson_fixture(%{difficulty: 5, title: "N5 Lesson"})
      _n4_lesson = lesson_fixture(%{difficulty: 4, title: "N4 Lesson"})

      # Navigate to N5 filter
      {:ok, _view, html} = live(conn, ~p"/lessons?difficulty=5")
      assert html =~ "N5"
      assert html =~ "lessons"

      # Navigate to N4 filter
      {:ok, _view, html} = live(conn, ~p"/lessons?difficulty=4")
      assert html =~ "N4"
      assert html =~ "lessons"
    end

    test "displays lesson count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "lessons"
    end

    test "shows empty state when no lessons", %{conn: conn} do
      # Test with difficulty that has no lessons (N1)
      {:ok, view, _html} = live(conn, ~p"/lessons?difficulty=1")

      assert render(view) =~ "No lessons found"
    end

    test "shows lesson number and word count", %{conn: conn} do
      # Create lesson with words
      lesson_with_words = lesson_with_words_fixture()

      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "#{length(lesson_with_words.lesson_words)} words"
    end

    test "authenticated user can access lesson browser", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "Lessons"
    end
  end

  describe "Show" do
    setup [:create_lesson_with_words, :create_user]

    test "displays lesson details", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ lesson.title
      assert html =~ lesson.description
    end

    test "displays lesson number and difficulty badges", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Lesson #{lesson.order_index}"
      assert html =~ "JLPT N#{lesson.difficulty}"
    end

    test "displays words in lesson", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Words in this Lesson"

      # Check that each word is displayed
      for lw <- lesson.lesson_words do
        assert html =~ lw.word.text
        assert html =~ lw.word.meaning
      end
    end

    test "has back link to lesson list", %{conn: conn, lesson: lesson} do
      {:ok, view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Back to N#{lesson.difficulty} Lessons"
      assert has_element?(view, "a[href='/lessons?difficulty=#{lesson.difficulty}']")
    end

    test "shows start learning button for authenticated user", %{
      conn: conn,
      lesson: lesson,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Start Learning"
    end

    test "shows sign in button for anonymous user", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Sign in to Start Learning"
    end

    test "shows progress section for authenticated user", %{
      conn: conn,
      lesson: lesson,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Your Progress"
      assert html =~ "0/#{length(lesson.lesson_words)} words learned"
    end

    test "does not show progress section for anonymous user", %{conn: conn, lesson: lesson} do
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      refute html =~ "Your Progress"
    end

    test "404 for non-existent lesson", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/lessons/#{Ecto.UUID.generate()}")
      end
    end
  end

  defp create_lesson(_) do
    lesson = lesson_fixture()
    %{lesson: lesson}
  end

  defp create_lesson_with_words(_) do
    lesson = lesson_with_words_fixture()
    %{lesson: lesson}
  end

  defp create_user(_) do
    user = user_fixture()
    %{user: user}
  end
end
