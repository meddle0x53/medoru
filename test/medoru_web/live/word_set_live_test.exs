defmodule MedoruWeb.WordSetLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Content
  alias Medoru.Learning.WordSets

  setup %{conn: conn} do
    user = user_fixture(%{type: "teacher"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "Show word set" do
    test "shows create vocabulary lesson button for teacher owner", %{conn: conn, user: user} do
      word_set = word_set_fixture(%{user_id: user.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      assert html =~ "Create Vocabulary Lesson"
    end

    test "hides create vocabulary lesson button for students", %{conn: _conn} do
      student = user_fixture(%{type: "student"})
      word_set = word_set_fixture(%{user_id: student.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      conn = log_in_user(build_conn(), student)
      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      refute html =~ "Create Vocabulary Lesson"
    end

    test "creates a vocabulary lesson from the word set", %{conn: conn, user: user} do
      word_set = word_set_fixture(%{user_id: user.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      view
      |> element("button[phx-click='create_lesson']")
      |> render_click()

      # Verify lesson was created from the word set
      lessons = Content.list_teacher_custom_lessons(user.id)
      assert length(lessons) == 1

      lesson = hd(lessons)
      assert lesson.title == word_set.name
      assert lesson.lesson_subtype == "vocabulary"
      assert lesson.word_count == 1

      assert_redirect(view, ~p"/teacher/custom-lessons/#{lesson.id}/edit")
    end
  end
end
