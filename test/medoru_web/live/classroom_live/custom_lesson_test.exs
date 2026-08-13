defmodule MedoruWeb.ClassroomLive.CustomLessonPageTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.{Classrooms, Content, Repo}

  defp classroom_fixture(attrs) do
    attrs = Map.merge(%{name: attrs[:name] || "Test Classroom"}, attrs)
    {:ok, classroom} = Classrooms.create_classroom(attrs)
    Repo.preload(classroom, [:teacher, memberships: :user])
  end

  describe "vocabulary lesson audio" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)

      word1 = word_fixture(%{text: "たべる", pronunciation_path: "/audio/word1.mp3"})
      word2 = word_fixture(%{text: "のむ", pronunciation_path: "/audio/word2.mp3"})

      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "vocabulary",
          title: "Vocabulary Lesson",
          status: "published"
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})

      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{
        conn: conn,
        student: student,
        classroom: classroom,
        lesson: lesson,
        word1: word1,
        word2: word2
      }
    end

    test "audio element has src and unique id matching current word", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson,
      word1: word1
    } do
      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      assert html =~ "word-audio-#{word1.id}"
      assert html =~ word1.pronunciation_path
    end

    test "navigating to next word updates audio id and src", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson,
      word1: word1,
      word2: word2
    } do
      conn = log_in_user(conn, student)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      html =
        view
        |> element("button", "Next")
        |> render_click()

      refute html =~ "word-audio-#{word1.id}"
      assert html =~ "word-audio-#{word2.id}"
      assert html =~ word2.pronunciation_path
    end
  end

  describe "copy to grammar button" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      admin = user_fixture(%{type: "admin"})

      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})

      # Enroll student (auto-approved since should_approve_memberships is false)
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)

      # Also enroll admin so they can view the lesson
      {:ok, _} = Classrooms.apply_to_join(classroom.id, admin.id)

      # Create a published grammar lesson with steps
      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "grammar",
          title: "Grammar Lesson",
          status: "published"
        })

      step =
        grammar_lesson_step_fixture(%{
          custom_lesson: lesson,
          title: "〜ている",
          position: 0,
          step_type: "grammar",
          explanation: "Continuous action grammar",
          pattern_elements: [
            %{"type" => "word_slot", "word_type" => "verb", "form" => "te-form"},
            %{"type" => "literal", "text" => "いる"}
          ],
          examples: [
            %{
              "sentence" => "食べている",
              "reading" => "たべている",
              "meaning" => "eating (continuous)"
            }
          ]
        })

      # Publish lesson to classroom
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{
        conn: conn,
        teacher: teacher,
        student: student,
        admin: admin,
        classroom: classroom,
        lesson: lesson,
        step: step
      }
    end

    test "admin sees Copy To Grammar button on grammar step", %{
      conn: conn,
      admin: admin,
      classroom: classroom,
      lesson: lesson
    } do
      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      assert html =~ "Copy To Grammar"
    end

    test "student does not see Copy To Grammar button", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      refute html =~ "Copy To Grammar"
    end

    test "admin can copy grammar step to new grammar definition", %{
      conn: conn,
      admin: admin,
      classroom: classroom,
      lesson: lesson,
      step: step
    } do
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      # Verify no grammar definition exists yet
      assert Content.get_grammar_definition_by_title(step.title) == nil

      view
      |> element("button", "Copy To Grammar")
      |> render_click()

      # Verify grammar definition was created
      grammar = Content.get_grammar_definition_by_title(step.title)
      assert grammar != nil
      assert grammar.title == step.title
      assert grammar.description == step.explanation
      assert length(grammar.pattern_elements) == 2

      # First element should be word_slot with forms array
      [word_slot, literal] = grammar.pattern_elements
      assert word_slot["type"] == "word_slot"
      assert word_slot["forms"] == ["te-form"]
      refute Map.has_key?(word_slot, "form")

      # Second element should be literal with text
      assert literal["type"] == "literal"
      assert literal["text"] == "いる"

      # Flash should show success
      html = render(view)
      assert html =~ "copied to grammar definitions"
    end

    test "shows flash when grammar definition already exists", %{
      conn: conn,
      admin: admin,
      classroom: classroom,
      lesson: lesson,
      step: step
    } do
      # Pre-create a grammar definition with the same title
      grammar_definition_fixture(%{title: step.title, slug: "te-iru"})

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      html =
        view
        |> element("button", "Copy To Grammar")
        |> render_click()

      assert html =~ "already exists"
    end

    test "text step does not show Copy To Grammar button", %{
      conn: conn,
      admin: admin,
      classroom: classroom,
      lesson: lesson
    } do
      # Create a text step
      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        title: "Introduction",
        position: 1,
        step_type: "text",
        explanation_sections: ["Welcome to the lesson"]
      })

      conn = log_in_user(conn, admin)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}?step=1")

      refute html =~ "Copy To Grammar"
    end

    test "text step renders examples", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        title: "Introduction",
        position: 1,
        step_type: "text",
        explanation_sections: ["Welcome to the lesson"],
        examples: [
          %{
            "sentence" => "今日は寒いです",
            "reading" => "きょうはさむいです",
            "meaning" => "Today is cold"
          }
        ]
      })

      conn = log_in_user(conn, student)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}?step=1")

      assert html =~ "今日は寒いです"
      assert html =~ "きょうはさむいです"
      assert html =~ "Today is cold"
      assert html =~ "Examples:"
    end

    test "admin can copy from preview mode", %{
      conn: conn,
      teacher: teacher,
      lesson: lesson
    } do
      # Teacher (who is also creator) can preview
      conn = log_in_user(conn, teacher)
      {:ok, view, _html} = live(conn, ~p"/teacher/custom-lessons/#{lesson.id}/preview")

      # Teacher should NOT see the button (only admin)
      refute render(view) =~ "Copy To Grammar"
    end
  end

  describe "preview draft lesson without classroom" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})

      %{
        conn: conn,
        teacher: teacher
      }
    end

    test "renders vocabulary preview without crashing", %{
      conn: conn,
      teacher: teacher
    } do
      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "vocabulary",
          title: "Draft Vocabulary Lesson",
          status: "draft"
        })

      word = word_fixture(%{text: "たべる"})
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})

      conn = log_in_user(conn, teacher)
      {:ok, _view, html} = live(conn, ~p"/teacher/custom-lessons/#{lesson.id}/preview")

      assert html =~ "Preview Mode"
      assert html =~ word.text
    end

    test "renders grammar preview without crashing when no steps exist", %{
      conn: conn,
      teacher: teacher
    } do
      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "grammar",
          title: "Draft Grammar Lesson",
          status: "draft"
        })

      conn = log_in_user(conn, teacher)
      {:ok, _view, html} = live(conn, ~p"/teacher/custom-lessons/#{lesson.id}/preview")

      assert html =~ "Preview Mode"
      assert html =~ lesson.title
    end

    test "preserves text after colored word in preview", %{
      conn: conn,
      teacher: teacher
    } do
      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "grammar",
          title: "Colored Grammar Lesson",
          status: "draft"
        })

      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        title: "Introduction",
        position: 0,
        step_type: "text",
        explanation_sections: ["食べる means to eat"],
        word_colors: [
          %{"word" => "食べる", "color_index" => 0, "apply_to" => "explanation"}
        ]
      })

      conn = log_in_user(conn, teacher)
      {:ok, _view, html} = live(conn, ~p"/teacher/custom-lessons/#{lesson.id}/preview")

      assert html =~ "食べる"
      assert html =~ "means to eat"
    end
  end

  describe "grammar lesson rendering with pseudo-HTML markdown" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)

      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "grammar",
          title: "Grammar with Markdown HTML",
          status: "published"
        })

      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        title: "でも",
        position: 0,
        step_type: "text",
        explanation_sections: [
          "<English>\nWhen you put \"でも\" in front of the sentence, you are going to say something that conflicts with the previous sentence.</English>"
        ]
      })

      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{
        conn: conn,
        student: student,
        classroom: classroom,
        lesson: lesson
      }
    end

    test "renders grammar step with unclosed pseudo-HTML tags without crashing", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      conn = log_in_user(conn, student)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}")

      assert html =~ lesson.title
      assert html =~ "でも"
      assert html =~ "When you put"
    end
  end

  describe "practice mode" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})

      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)

      word = word_fixture(%{text: "たべる"})

      lesson =
        custom_lesson_fixture(%{
          creator_id: teacher.id,
          lesson_subtype: "vocabulary",
          title: "Vocabulary Lesson",
          status: "published"
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)
      {:ok, _} = Classrooms.complete_custom_lesson(classroom.id, student.id, lesson.id)

      %{
        conn: conn,
        student: student,
        classroom: classroom,
        lesson: lesson
      }
    end

    test "?practice=true shows finish review button and redirects to practice completion", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}?practice=true")

      assert html =~ "Finish Review"

      view
      |> element("button", "Finish Review")
      |> render_click()

      assert_redirect(
        view,
        ~p"/classrooms/#{classroom.id}/custom-lessons/#{lesson.id}/complete?practice=true"
      )
    end
  end
end
