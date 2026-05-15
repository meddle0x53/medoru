defmodule MedoruWeb.LessonLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.{Classrooms, Content}

  describe "Index" do
    test "anonymous user sees sign-in prompt", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "Lessons"
      assert html =~ "Sign in to see your lessons"
      assert html =~ "Sign in with Google"
    end

    test "authenticated user with no classrooms sees empty state", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "Lessons"
      assert html =~ "No Lessons Available"
      assert html =~ "Browse Classrooms"
    end

    test "authenticated user sees classroom lessons", %{conn: conn} do
      teacher = user_fixture()
      student = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      custom_lesson = custom_lesson_fixture(%{creator_id: teacher.id, status: "published"})

      {:ok, _ccl} =
        Content.publish_lesson_to_classroom(custom_lesson.id, classroom.id, teacher.id)

      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, student.id)

      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "Lessons"
      assert html =~ custom_lesson.title
      assert html =~ "Test Classroom"
      assert html =~ "Not Started"
    end

    test "authenticated user sees completed lesson status", %{conn: conn} do
      teacher = user_fixture()
      student = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      custom_lesson = custom_lesson_fixture(%{creator_id: teacher.id, status: "published"})

      {:ok, _ccl} =
        Content.publish_lesson_to_classroom(custom_lesson.id, classroom.id, teacher.id)

      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, student.id)

      # Mark lesson as completed
      {:ok, _progress} =
        Classrooms.complete_custom_lesson(classroom.id, student.id, custom_lesson.id)

      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ custom_lesson.title
      assert html =~ "Completed"
    end

    test "shows word count for classroom lessons", %{conn: conn} do
      teacher = user_fixture()
      student = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      custom_lesson =
        custom_lesson_fixture(%{creator_id: teacher.id, status: "published", word_count: 15})

      {:ok, _ccl} =
        Content.publish_lesson_to_classroom(custom_lesson.id, classroom.id, teacher.id)

      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, student.id)

      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/lessons")

      assert html =~ "15"
      assert html =~ "words"
    end

    test "paginates classroom lessons", %{conn: conn} do
      teacher = user_fixture()
      student = user_fixture()

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      # Create 21 lessons to trigger pagination (default per_page is 20)
      for i <- 1..21 do
        lesson =
          custom_lesson_fixture(%{
            creator_id: teacher.id,
            status: "published",
            title: "Lesson #{String.pad_leading("#{i}", 2, "0")}"
          })

        {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)
      end

      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, student.id)

      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/lessons")

      # First page shows the 20 newest lessons and pagination
      assert html =~ "Lesson 21"
      assert html =~ "Lesson 02"
      refute html =~ "Lesson 01"
      assert html =~ "1 / 2"

      # Navigate to page 2
      {:ok, _view, html} = live(conn, ~p"/lessons?page=2")

      assert html =~ "Lesson 01"
      refute html =~ "Lesson 21"
      assert html =~ "2 / 2"
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

      assert html =~ "Back to N"
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

      assert html =~ "Preview Lesson"
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

    test "shows completed status for completed lesson", %{
      conn: conn,
      lesson: lesson,
      user: user
    } do
      conn = log_in_user(conn, user)

      # Create a completed lesson progress
      {:ok, _progress} =
        Medoru.Learning.start_lesson(user.id, lesson.id)

      {:ok, progress} =
        Medoru.Learning.complete_lesson(user.id, lesson.id)

      assert progress.progress_percentage == 100

      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Completed!"
      assert html =~ "Review Lesson"
    end

    test "404 for non-existent lesson", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/lessons/#{Ecto.UUID.generate()}")
      end
    end
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
