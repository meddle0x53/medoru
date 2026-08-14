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
      assert has_element?(view, "a", "Create Vocabulary Lesson")
      assert has_element?(view, "a", "Create Grammar Lesson")
    end

    test "student cannot access custom lessons", %{conn: conn, student: student} do
      {:error, {:redirect, %{to: "/dashboard", flash: flash}}} =
        conn |> log_in_user(student) |> live(~p"/teacher/custom-lessons")

      assert flash["error"] == "You must be a teacher to access this page."
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

      assert has_element?(
               view,
               "a[href=\"/teacher/custom-lessons/#{lesson.id}/preview\"]",
               "Preview"
             )
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

      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

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

      # Redirected to publish page; lesson stays draft until a classroom is chosen
      assert_redirected(view, ~p"/teacher/custom-lessons/#{lesson.id}/publish")

      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/custom-lessons/#{lesson.id}/publish")

      view
      |> element("button[phx-click='publish']")
      |> render_click(%{"classroom_id" => classroom.id})

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

      # Lesson should revert to draft when no longer published to any classroom
      lesson = Content.get_custom_lesson!(lesson.id)
      assert lesson.status == "draft"
    end

    test "requires_test generates test on publish", %{conn: conn, teacher: teacher} do
      word = word_fixture()

      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Lesson with Test",
          creator_id: teacher.id,
          status: "draft",
          requires_test: true
        })

      # Add word to lesson
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      # Start publishing the lesson
      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      view
      |> element("button", "Publish")
      |> render_click()

      assert_redirected(view, ~p"/teacher/custom-lessons/#{lesson.id}/publish")

      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/custom-lessons/#{lesson.id}/publish")

      view
      |> element("button[phx-click='publish']")
      |> render_click(%{"classroom_id" => classroom.id})

      # Verify lesson is published and test was generated
      published = Content.get_custom_lesson!(lesson.id)
      assert published.status == "published"
      assert published.test_id != nil
    end

    test "cannot publish grammar lesson with requires_test and no testable steps", %{
      conn: conn,
      teacher: teacher
    } do
      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Grammar Lesson Without Testable Steps",
          creator_id: teacher.id,
          status: "draft",
          lesson_subtype: "grammar",
          requires_test: true,
          word_count: 1
        })

      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        position: 0,
        title: "Step Without Examples",
        include_in_test: true,
        examples: []
      })

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      view
      |> element("button", "Publish")
      |> render_click()

      assert render(view) =~
               "At least 1 grammar step must be included in the test and have examples."
    end

    test "teacher can reorder lesson words", %{conn: conn, teacher: teacher} do
      word1 = word_fixture(%{text: "日本", reading: "にほん", meaning: "Japan"})
      word2 = word_fixture(%{text: "学校", reading: "がっこう", meaning: "school"})

      {:ok, lesson} =
        Content.create_custom_lesson(%{
          title: "Reorder Lesson",
          creator_id: teacher.id,
          status: "draft"
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/custom-lessons/#{lesson.id}/edit")

      # Verify initial order
      initial_html = render(view)
      assert initial_html =~ ~r/日本.*学校/s

      # Send reorder event (simulating the WordSorter hook)
      render_hook(view, "reorder", %{word_ids: [word2.id, word1.id]})

      # Verify order flipped in the database
      lesson_words = Content.list_lesson_words(lesson.id)
      assert Enum.map(lesson_words, & &1.word_id) == [word2.id, word1.id]
      assert Enum.map(lesson_words, & &1.position) == [0, 1]

      # Verify the UI reflects the new order
      updated_html = render(view)
      assert updated_html =~ ~r/学校.*日本/s
    end
  end
end
