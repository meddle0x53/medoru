defmodule MedoruWeb.ClassroomLive.TestTest do
  @moduledoc """
  Tests for the classroom test taking experience.

  Covers:
  - Starting a test
  - Answering questions
  - Timer sync
  - Auto-submit on time up
  - Test results display
  - Resume in-progress tests
  """
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.TestsFixtures

  alias Medoru.Classrooms
  alias Medoru.Tests

  describe "Test taking" do
    setup do
      teacher = user_fixture(%{email: "teacher@example.com"})
      student = user_fixture(%{email: "student@example.com"})

      # Create a classroom
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      # Add student as approved member
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      # Create a test with steps
      test =
        test_fixture(%{
          title: "Sample Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 10
        })

      # Create test steps
      step1 =
        test_step_fixture(test, %{
          question: "What is 日本?",
          question_type: :multichoice,
          correct_answer: "Japan",
          options: ["Japan", "China", "Korea", "India"],
          order_index: 0
        })

      step2 =
        test_step_fixture(test, %{
          question: "How do you read 'ありがとう'?",
          question_type: :fill,
          correct_answer: "thank you",
          order_index: 1
        })

      # Publish test to classroom
      {:ok, classroom_test} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test.id,
          teacher.id,
          %{max_attempts: 1}
        )

      %{
        teacher: teacher,
        student: student,
        classroom: classroom,
        test_resource: test,
        step1: step1,
        step2: step2,
        classroom_test: classroom_test
      }
    end

    test "mounts test page for approved member", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert html =~ test_resource.title
      assert html =~ "Question 1 of 2"
      assert render(view) =~ "What is 日本?"
    end

    test "redirects non-member to classrooms list", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      other_user = user_fixture(%{email: "other@example.com"})
      conn = log_in_user(conn, other_user)

      {:error, {:live_redirect, %{to: "/classrooms"}}} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")
    end

    test "redirects pending member to classroom", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      pending_user = user_fixture(%{email: "pending@example.com"})
      {:ok, _} = Classrooms.apply_to_join(classroom.id, pending_user.id)
      # Don't approve

      conn = log_in_user(conn, pending_user)

      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert path =~ "/classrooms/#{classroom.id}"
    end

    test "submitting answer moves to next question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Submit answer to first question
      view
      |> form("form", %{answer: "Japan"})
      |> render_submit()

      # Should now show question 2
      assert render(view) =~ "Question 2 of 2"
      assert render(view) =~ "How do you read"
    end

    test "completing test redirects to results", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Answer first question
      view
      |> form("form", %{answer: "Japan"})
      |> render_submit()

      # Answer second question
      view
      |> form("form", %{answer: %{"meaning" => "thank you", "_dummy" => "1"}})
      |> render_submit()

      # Should redirect to results
      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")
    end

    test "time_up event auto-submits test", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Simulate timer running out
      render_hook(view, "time_up", %{})

      # Should redirect to results with auto-submitted flag
      flash =
        assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      assert flash["warning"] =~ "Time's up"
    end

    test "sync_time event updates time remaining in DB", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Simulate time sync from client
      render_hook(view, "sync_time", %{"time_remaining" => 300})

      # Wait a bit for the async update
      Process.sleep(100)

      # Verify attempt was updated
      attempt = Classrooms.get_test_attempt(classroom.id, student.id, test_resource.id)
      assert attempt.time_remaining_seconds == 300
    end

    test "resumes in-progress test", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Start test and answer first question
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Japan"})
      |> render_submit()

      # Navigate away (simulate)

      # Come back - should resume at question 2
      {:ok, _view2, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert html =~ "Question 2 of 2"
    end

    test "shows error for already completed test", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Complete the test first
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Japan"})
      |> render_submit()

      view
      |> form("form", %{answer: %{"meaning" => "thank you", "_dummy" => "1"}})
      |> render_submit()

      # Wait for redirect and process
      _ =
        assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      # Try to access test again - should redirect with message
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert path =~ "/classrooms/#{classroom.id}"
    end
  end

  describe "Test results page" do
    setup do
      teacher = user_fixture(%{email: "teacher2@example.com"})
      student = user_fixture(%{email: "student2@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Results Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      test =
        test_fixture(%{
          title: "Results Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 10
        })

      step1 =
        test_step_fixture(test, %{
          question: "Q1",
          question_type: :multichoice,
          correct_answer: "Correct",
          options: ["Correct", "Wrong1", "Wrong2", "Wrong3"],
          order_index: 0,
          explanation: "This is why"
        })

      step2 =
        test_step_fixture(test, %{
          question: "Q2",
          question_type: :multichoice,
          correct_answer: "Right",
          options: ["Right", "WrongA", "WrongB", "WrongC"],
          order_index: 1
        })

      {:ok, _} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test.id,
          teacher.id,
          %{max_attempts: 1}
        )

      %{
        teacher: teacher,
        student: student,
        classroom: classroom,
        test_resource: test,
        step1: step1,
        step2: step2
      }
    end

    test "displays test results after completion", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Complete the test
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      view
      |> form("form", %{answer: "WrongA"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      # View results
      {:ok, _results_view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      assert html =~ "Test Results"
      assert html =~ test_resource.title
      # Should show percentage
      assert html =~ "%"
      # Should show score format
      assert html =~ "/"
    end

    test "shows correct and incorrect answers", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Complete test with one correct, one wrong
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      view
      |> form("form", %{answer: "WrongA"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      {:ok, _results_view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      # Should show correct/incorrect badges
      assert html =~ "Correct"
      assert html =~ "Incorrect"

      # Should show correct answer for wrong question
      # Correct answer for Q2
      assert html =~ "Right"
    end

    test "shows explanation when available", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Complete test
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      view
      |> form("form", %{answer: "Right"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      {:ok, _results_view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      # Explanation from step1
      assert html =~ "This is why"
    end

    test "redirects if no completed test found", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      # Try to view results without completing
      {:error, {:live_redirect, %{to: path}}} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      assert path =~ "/classrooms/#{classroom.id}"
    end
  end

  describe "Fill/typing questions" do
    setup do
      teacher = user_fixture(%{email: "teacher3@example.com"})
      student = user_fixture(%{email: "student3@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Fill Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      word = word_fixture(%{text: "猫", meaning: "cat", reading: "ねこ"})

      test =
        test_fixture(%{
          title: "Fill Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 5
        })

      step =
        test_step_fixture(test, %{
          question: "What does '猫' mean?",
          question_type: :fill,
          correct_answer: "cat",
          order_index: 0,
          question_data: %{
            "word_id" => word.id,
            "include_reading" => false
          }
        })

      {:ok, _} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test.id,
          teacher.id,
          %{max_attempts: 1}
        )

      %{
        teacher: teacher,
        student: student,
        classroom: classroom,
        test_resource: test,
        step: step,
        word: word
      }
    end

    test "submitting fill question with meaning only", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Should show fill input
      assert html =~ "Meaning (in English)"

      # Submit with correct meaning
      view
      |> form("form", %{answer: %{"meaning" => "cat", "_dummy" => "1"}})
      |> render_submit()

      # Should complete test and redirect
      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")
    end

    test "partial credit for fill questions with reading", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource,
      step: step
    } do
      # Update step to include reading
      {:ok, _updated_step} =
        Tests.update_test_step(step, %{
          question_data: %{
            "word_id" => step.question_data["word_id"],
            "include_reading" => true,
            "reading_answer" => "ねこ"
          }
        })

      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Should show both meaning and reading inputs
      assert html =~ "Reading (in Hiragana)"

      # Submit with correct meaning but wrong reading
      view
      |> form("form", %{
        answer: %{"meaning" => "cat", "reading" => "wrong", "_dummy" => "1"}
      })
      |> render_submit()

      # Complete test
      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      # Verify partial score
      attempt = Classrooms.get_test_attempt(classroom.id, student.id, test_resource.id)
      # Partial credit for meaning only
      assert attempt.score == 2
    end
  end
end
