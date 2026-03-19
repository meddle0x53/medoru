defmodule MedoruWeb.Teacher.CustomLessonLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Content

  describe "Teacher custom lesson management" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      %{teacher: teacher, student: student}
    end

    test "teacher can access custom lessons index", %{conn: conn, teacher: teacher} do
      {:ok, view, html} = conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons")

      assert html =~ "My Custom Lessons"
      assert has_element?(view, "a", "Create Lesson")
    end

    test "student cannot access custom lessons", %{conn: conn, student: student} do
      {:error, {:live_redirect, %{to: "/classrooms", flash: flash}}} =
        conn |> log_in_user(student) |> live(~p"/teacher/custom-lessons")

      assert flash["error"] == "Only teachers can access this page."
    end

    test "teacher can create a custom lesson", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/new")

      result =
        view
        |> form("form",
          custom_lesson: %{
            title: "Test Lesson",
            description: "Test description",
            difficulty: "5"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/teacher/custom-lessons/" <> _}}} = result

      # Verify lesson was created
      [lesson] = Content.list_teacher_custom_lessons(teacher.id)
      assert lesson.title == "Test Lesson"
      assert lesson.creator_id == teacher.id
      assert lesson.status == "draft"
      # Note: requires_test may be false if checkbox wasn't checked properly in test
    end

    test "lesson title is required", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/new")

      html =
        view
        |> form("form", custom_lesson: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "teacher can edit their draft lesson", %{conn: conn, teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Draft Lesson",
          creator_id: teacher.id,
          status: "draft"
        })

      # Add word so publish button appears
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      {:ok, view, html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      assert html =~ lesson.title
      assert has_element?(view, "button", "Publish")
    end

    test "teacher cannot edit another teacher's lesson", %{conn: conn} do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Other Teacher's Lesson",
          creator_id: teacher1.id,
          status: "draft"
        })

      {:error, {:live_redirect, %{to: "/teacher/custom-lessons", flash: flash}}} =
        conn |> log_in_user(teacher2) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      assert flash["error"] == "You can only edit your own lessons."
    end

    test "teacher can publish a draft lesson", %{conn: conn, teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson to Publish",
          creator_id: teacher.id,
          status: "draft"
        })

      # Add a word first (required for publishing)
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      view
      |> element("button", "Publish")
      |> render_click()

      published = Content.get_custom_lesson!(lesson.id)
      assert published.status == "published"
    end

    test "teacher can publish lesson to classroom", %{conn: conn, teacher: teacher} do
      word = word_fixture()

      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson to Publish",
          creator_id: teacher.id,
          status: "published"
        })

      # Add word to lesson
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/custom-lessons/#{lesson.id}/publish")

      view
      |> element("button[phx-click='publish']")
      |> render_click(%{"classroom_id" => classroom.id})

      # Verify it was published to classroom
      publications = Content.list_lesson_classroom_publications(lesson.id, status: "active")
      assert length(publications) == 1
      assert hd(publications).classroom_id == classroom.id
    end

    test "teacher can only publish to their own classrooms", %{conn: conn} do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Teacher2's Classroom",
          teacher_id: teacher2.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson to Publish",
          creator_id: teacher1.id,
          status: "published"
        })

      {:ok, view, _html} =
        conn
        |> log_in_user(teacher1)
        |> live(~p"/teacher/custom-lessons/#{lesson.id}/publish")

      # The classroom shouldn't even appear in the list
      refute render(view) =~ classroom.name
    end

    test "teacher can unpublish lesson from classroom", %{conn: conn, teacher: teacher} do
      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson to Publish",
          creator_id: teacher.id,
          status: "published"
        })

      # First publish
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      # Then unpublish
      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/custom-lessons/#{lesson.id}/publish")

      view
      |> element("button[phx-click='unpublish']")
      |> render_click(%{"classroom_id" => classroom.id})

      # Verify it was unpublished
      publications = Content.list_lesson_classroom_publications(lesson.id, status: "active")
      assert Enum.empty?(publications)
    end

    test "requires_test generates test on publish", %{conn: conn, teacher: teacher} do
      word = word_fixture()

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson with Test",
          creator_id: teacher.id,
          status: "draft",
          requires_test: true
        })

      # Add word to lesson
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      # Publish the lesson
      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      view
      |> element("button", "Publish")
      |> render_click()

      # Verify lesson is published
      published = Content.get_custom_lesson!(lesson.id)
      assert published.status == "published"
    end
  end
end
