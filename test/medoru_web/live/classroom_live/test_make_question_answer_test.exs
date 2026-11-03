defmodule MedoruWeb.ClassroomLive.TestMakeQuestionAnswerTest do
  @moduledoc """
  Tests for the "make a question and answer it" step type in the classroom
  test assignment view.
  """
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.{Accounts, Classrooms, Content, Repo, Tests}
  alias Medoru.Tests.TestSession

  @question_data %{
    "requirement" => "家へ 行く（はい）",
    "expected_question" => "家へ行けますか。",
    "expected_answer" => "はい、行けます。",
    "expected_question_reading" => "いえへいけますか",
    "expected_answer_reading" => "はいいけます",
    "examples" => ["家へ 行く（はい）\n家へ行けますか。\n……はい、行けます。"]
  }

  setup %{conn: conn} do
    {:ok, teacher} =
      Accounts.register_user_with_oauth(%{
        email: "teacher-mqa@example.com",
        provider: "google",
        provider_uid: "teacher-mqa"
      })

    {:ok, student} =
      Accounts.register_user_with_oauth(%{
        email: "student-mqa@example.com",
        provider: "google",
        provider_uid: "student-mqa"
      })

    {:ok, classroom} =
      Classrooms.create_classroom(%{name: "MQA Classroom", teacher_id: teacher.id})

    {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
    {:ok, _} = Classrooms.approve_membership(membership)

    # Word fixture so kanji input converts to kana during grading
    {:ok, _word} =
      Content.create_word(%{
        text: "家",
        reading: "いえ",
        meaning: "house",
        word_type: :noun,
        difficulty: 1
      })

    {:ok, test_resource} =
      Tests.create_test(%{
        title: "MQA Test",
        description: "Make question and answer",
        created_by_id: teacher.id,
        test_type: :teacher,
        status: :published,
        total_points: 10,
        time_limit_seconds: 600
      })

    {:ok, _step} =
      Tests.create_test_step(test_resource, %{
        question: "Make a question in the pattern and answer it",
        question_type: :grammar_make_question_answer,
        step_type: :grammar,
        order_index: 0,
        question_data: @question_data,
        options: [],
        correct_answer: "N/A",
        points: 10,
        kanji_id: nil,
        word_id: nil
      })

    {:ok, _classroom_test} =
      Classrooms.publish_test_to_classroom(
        classroom.id,
        test_resource.id,
        teacher.id,
        %{
          due_date: DateTime.utc_now() |> DateTime.add(7, :day),
          max_attempts: 1,
          time_limit_seconds: 600
        }
      )

    conn = log_in_user(conn, student)

    {:ok, conn: conn, student: student, classroom: classroom, test_resource: test_resource}
  end

  test "student sees examples, requirement, and two inputs", %{
    conn: conn,
    classroom: classroom,
    test_resource: test_resource
  } do
    {:ok, view, html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    assert html =~ "家へ 行く（はい）"
    assert html =~ "Requirement"
    assert html =~ "Write your question"
    assert html =~ "Write your answer"

    assert has_element?(view, "input[name='make_question_answer[question]']")
    assert has_element?(view, "input[name='make_question_answer[answer]']")
  end

  test "submitting both parts correct records full points", %{
    conn: conn,
    student: student,
    classroom: classroom,
    test_resource: test_resource
  } do
    {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    view
    |> form("form[phx-submit='submit_answer']", %{
      make_question_answer: %{question: "家へいけますか。", answer: "はい、いけます。"}
    })
    |> render_submit()

    [answer] = recorded_answers(student.id, test_resource.id)
    assert answer.is_correct == true
    assert answer.points_earned == 10
  end

  test "submitting only one part correct records half points", %{
    conn: conn,
    student: student,
    classroom: classroom,
    test_resource: test_resource
  } do
    {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    view
    |> form("form[phx-submit='submit_answer']", %{
      make_question_answer: %{question: "家へいけますか。", answer: "いいえ、いけません。"}
    })
    |> render_submit()

    [answer] = recorded_answers(student.id, test_resource.id)
    assert answer.is_correct == false
    assert answer.points_earned == 5
  end

  defp recorded_answers(user_id, test_id) do
    session = Repo.get_by!(TestSession, user_id: user_id, test_id: test_id)
    Tests.list_step_answers(session.id)
  end
end
