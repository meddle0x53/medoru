defmodule MedoruWeb.WordSetLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Content
  alias Medoru.Learning.WordBooks
  alias Medoru.Learning.WordSets
  alias Medoru.Notifications
  alias Medoru.Social

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

  describe "Create word book" do
    test "shows create word book button for owner regardless of user type", %{conn: _conn} do
      student = user_fixture(%{type: "student"})
      word_set = word_set_fixture(%{user_id: student.id})

      conn = log_in_user(build_conn(), student)
      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      assert html =~ "Create Word Book"
    end

    test "hides create word book button for non-owner", %{conn: conn} do
      owner = user_fixture()
      word_set = word_set_fixture(%{user_id: owner.id})

      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      refute html =~ "Create Word Book"
    end

    test "creates a word book from the word set", %{conn: conn, user: user} do
      word_set = word_set_fixture(%{user_id: user.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      view
      |> element("button[phx-click='create_word_book']")
      |> render_click()

      # Verify word book was created from the word set
      %{word_books: books} = WordBooks.list_user_word_books(user.id)
      assert length(books) == 1

      book = hd(books)
      assert book.title == word_set.name
      assert book.word_count == 1

      assert_redirect(view, ~p"/words/books/#{book.id}/edit-words")
    end

    test "shows an error when the word set has no words", %{conn: conn, user: user} do
      word_set = word_set_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      html =
        view
        |> element("button[phx-click='create_word_book']")
        |> render_click()

      assert html =~ "Add words to the set first."
      assert WordBooks.list_user_word_books(user.id).word_books == []
    end
  end

  describe "Share word set" do
    test "shows share button for owner", %{conn: conn, user: user} do
      word_set = word_set_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      assert html =~ "Share"
    end

    test "hides share button for non-owner", %{conn: _conn, user: user} do
      owner = user_fixture()
      word_set = word_set_fixture(%{user_id: owner.id})

      conn = log_in_user(build_conn(), user)
      {:ok, _view, html} = live(conn, ~p"/words/sets/#{word_set.id}")

      refute html =~ "phx-click=\"open_share_modal\""
      refute html =~ "Share"
    end

    test "opens share modal and lists mutual followers", %{conn: conn, user: user} do
      recipient = user_fixture_with_profile(%{name: "Mutual Friend"})

      Social.follow_user(user.id, recipient.id)
      Social.follow_user(recipient.id, user.id)

      word_set = word_set_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      html =
        view
        |> element("button[phx-click='open_share_modal']")
        |> render_click()

      assert html =~ "Share Word Set"
      assert html =~ "Mutual Friend"
    end

    test "does not list users who are not mutual followers", %{conn: conn, user: user} do
      only_follows = user_fixture_with_profile(%{name: "Only Follows"})
      only_follower = user_fixture_with_profile(%{name: "Only Follower"})

      Social.follow_user(user.id, only_follows.id)
      Social.follow_user(only_follower.id, user.id)

      word_set = word_set_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      html =
        view
        |> element("button[phx-click='open_share_modal']")
        |> render_click()

      assert html =~ "mutual followers yet."
      refute html =~ "Only Follows"
      refute html =~ "Only Follower"
    end

    test "sending share creates a pending share and notification", %{conn: conn, user: user} do
      recipient = user_fixture_with_profile()

      Social.follow_user(user.id, recipient.id)
      Social.follow_user(recipient.id, user.id)

      word_set = word_set_fixture(%{user_id: user.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      view
      |> element("button[phx-click='open_share_modal']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='share_word_set'][phx-value-recipient_id='#{recipient.id}']")
        |> render_click()

      assert html =~ "Word set shared successfully."

      assert length(Notifications.list_notifications_by_type(recipient.id, "word_set_share")) == 1
      assert length(WordSets.list_pending_received_word_set_shares(recipient.id)) == 1
    end

    test "shows error when sharing with a non-mutual user", %{conn: conn, user: user} do
      stranger = user_fixture_with_profile()
      word_set = word_set_fixture(%{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}")

      # Simulate the share event directly with a non-mutual recipient id
      html =
        view
        |> render_click("share_word_set", %{"recipient_id" => stranger.id})

      assert html =~ "You can only share with mutual followers."
    end
  end
end
