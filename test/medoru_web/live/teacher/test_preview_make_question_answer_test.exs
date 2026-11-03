defmodule MedoruWeb.Teacher.ClassroomLive.TestPreviewMakeQuestionAnswerTest do
  @moduledoc """
  Render test for the "make a question and answer it" step in the teacher
  test preview.
  """
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.{Accounts, Classrooms, Tests}

  test "teacher preview renders examples, requirement, and two inputs", %{conn: conn} do
    {:ok, teacher} =
      Accounts.register_user_with_oauth(%{
        email: "teacher-preview-mqa@example.com",
        provider: "google",
        provider_uid: "teacher-preview-mqa"
      })

    {:ok, classroom} =
      Classrooms.create_classroom(%{name: "Preview Classroom", teacher_id: teacher.id})

    {:ok, test_resource} =
      Tests.create_test(%{
        title: "Preview MQA Test",
        description: "preview",
        creator_id: teacher.id,
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
        question_data: %{
          "requirement" => "家へ 行く（はい）",
          "expected_question" => "家へ行けますか。",
          "expected_answer" => "はい、行けます。",
          "expected_question_reading" => "いえへいけますか",
          "expected_answer_reading" => "はいいけます",
          "examples" => ["家へ 行く（はい）\n家へ行けますか。\n……はい、行けます。"]
        },
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

    {:ok, view, html} =
      conn
      |> log_in_user(teacher)
      |> live("/classrooms/#{classroom.id}/tests/#{test_resource.id}/preview")

    assert html =~ "Make a question in the pattern and answer it"
    assert html =~ "家へ 行く（はい）"
    assert html =~ "Requirement"
    assert has_element?(view, "input[name='make_question_answer[question]']")
    assert has_element?(view, "input[name='make_question_answer[answer]']")
  end
end
