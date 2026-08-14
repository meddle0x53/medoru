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

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.TestsFixtures

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests
  alias Medoru.Tests.ClassroomVocabularyTestGenerator
  alias Medoru.Tests.ClassroomKanjiDrawingTestGenerator

  defp get_anonymous_session(test_id) do
    Medoru.Tests.TestSession
    |> where([ts], is_nil(ts.user_id) and ts.test_id == ^test_id)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Medoru.Repo.one!()
  end

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

  describe "Listening step audio" do
    setup do
      teacher = user_fixture(%{email: "listening_teacher@example.com"})
      student = user_fixture(%{email: "listening_student@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Listening Audio Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      test =
        test_fixture(%{
          title: "Listening Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 20
        })

      step1 =
        test_step_fixture(test, %{
          question: "Listen and select 1",
          step_type: :listening,
          question_type: :listening,
          correct_answer: "Answer 1",
          options: ["Answer 1", "Wrong 1"],
          points: 10,
          order_index: 0,
          question_data: %{"audio_path" => "/audio/listening-step-1.mp3"}
        })

      step2 =
        test_step_fixture(test, %{
          question: "Listen and select 2",
          step_type: :listening,
          question_type: :listening,
          correct_answer: "Answer 2",
          options: ["Answer 2", "Wrong 2"],
          points: 10,
          order_index: 1,
          question_data: %{"audio_path" => "/audio/listening-step-2.mp3"}
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

    test "each listening step renders its own audio source", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource,
      step1: step1,
      step2: step2
    } do
      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert html =~ "Question 1 of 2"
      assert html =~ "listening-step-1.mp3"
      assert html =~ "id=\"listening-audio-#{step1.id}\""
      refute html =~ "listening-step-2.mp3"

      view
      |> form("form", %{answer: "Answer 1"})
      |> render_submit()

      html = render(view)

      assert html =~ "Question 2 of 2"
      assert html =~ "listening-step-2.mp3"
      assert html =~ "id=\"listening-audio-#{step2.id}\""
      refute html =~ "listening-step-1.mp3"
    end

    test "listening step options are shuffled so the correct answer is not always first" do
      step = %Medoru.Tests.TestStep{
        question_type: :listening,
        options: ["Correct", "Wrong 1", "Wrong 2", "Wrong 3"]
      }

      results = Enum.map(1..50, fn _ -> MedoruWeb.ClassroomLive.Test.shuffled_options(step) end)
      distinct = Enum.uniq(results)

      assert length(distinct) > 1
      assert Enum.all?(results, &(Enum.sort(&1) == Enum.sort(step.options)))
    end
  end

  describe "Listening step hints" do
    setup do
      teacher = user_fixture(%{email: "listening_hint_teacher@example.com"})
      student = user_fixture(%{email: "listening_hint_student@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Listening Hint Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      test =
        test_fixture(%{
          title: "Listening Hint Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 10
        })

      step =
        test_step_fixture(test, %{
          question: "Listen and select",
          step_type: :listening,
          question_type: :listening,
          correct_answer: "Answer 1",
          options: ["Answer 1", "Wrong 1"],
          points: 10,
          order_index: 0,
          hints: ["This is a helpful hint"],
          question_data: %{"audio_path" => "/audio/listening-hint.mp3"}
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
        step: step
      }
    end

    test "renders hint button for listening step with hint", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert html =~ "Show Hint"
      refute html =~ "This is a helpful hint"
    end

    test "clicking hint button shows the hint and halves earned points", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource,
      step: step
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> element("button", "Show Hint")
      |> render_click()

      html = render(view)
      assert html =~ "This is a helpful hint"

      view
      |> form("form", %{answer: "Answer 1"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Medoru.Repo.one!()

      assert answer.is_correct
      assert answer.hints_used == 1
      assert answer.points_earned == 5
    end

    test "answering without using hint earns full points", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource,
      step: step
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form", %{answer: "Answer 1"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Medoru.Repo.one!()

      assert answer.is_correct
      assert answer.hints_used == 0
      assert answer.points_earned == 10
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

    test "records score, max score and elapsed time for authenticated results", %{
      conn: conn,
      student: student,
      classroom: classroom,
      test_resource: test_resource
    } do
      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      # Sync the timer so completion calculates real elapsed time rather than 0.
      view
      |> element("#test-timer")
      |> render_hook("sync_time", %{"time_remaining" => 590})

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      view
      |> form("form", %{answer: "WrongA"})
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      attempt = Classrooms.get_test_attempt(classroom.id, student.id, test_resource.id)
      assert attempt.score == 1
      assert attempt.max_score == 2
      assert attempt.time_spent_seconds == 10

      session = Tests.get_test_session(attempt.test_session_id)
      assert session.status == :completed
      assert session.score == 1
      assert session.total_possible == 2

      {:ok, _results_view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      assert html =~ "50%"
      assert html =~ "1 <span class=\"text-secondary\">/ 2</span>"
    end

    test "localizes kanji writing question on results page", %{
      conn: conn,
      student: student
    } do
      teacher = user_fixture(%{email: "writing_teacher@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Writing Results Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      test_resource =
        test_fixture(%{
          title: "Writing Results Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 5
        })

      kanji = kanji_fixture(%{character: "社", meanings: ["company", "firm"]})

      test_step_fixture(test_resource, %{
        step_type: :writing,
        question_type: :writing,
        question: "__MSG_WRITE_KANJI_FOR__|company, firm",
        correct_answer: kanji.character,
        kanji_id: kanji.id,
        points: 5,
        order_index: 0,
        question_data: %{
          "kanji" => kanji.character,
          "meanings" => kanji.meanings,
          "stroke_count" => kanji.stroke_count
        }
      })

      {:ok, _} =
        Classrooms.publish_test_to_classroom(
          classroom.id,
          test_resource.id,
          teacher.id,
          %{max_attempts: 1}
        )

      conn = log_in_user(conn, student)

      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      view
      |> form("form")
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      {:ok, _results_view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      refute html =~ "__MSG_WRITE_KANJI_FOR__"
      assert html =~ "Write the kanji for"
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

  describe "Generated vocabulary tests" do
    setup do
      teacher = user_fixture(%{email: "gen_teacher@example.com"})
      student = user_fixture(%{email: "gen_student@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Generated Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      lesson = custom_lesson_fixture(%{creator_id: teacher.id, lesson_subtype: "vocabulary"})

      word_with_reading =
        word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})

      image_words =
        [
          %{text: "写真", meaning: "photo", reading: "しゃしん"},
          %{text: "絵", meaning: "picture", reading: "え"},
          %{text: "地図", meaning: "map", reading: "ちず"},
          %{text: "本", meaning: "book", reading: "ほん"}
        ]
        |> Enum.with_index()
        |> Enum.map(fn {attrs, i} ->
          word_fixture(
            attrs
            |> Map.put(:image_path, "/uploads/#{i}.jpg")
            |> Map.to_list()
          )
        end)

      image_word = hd(image_words)

      word_with_kanji = word_with_kanji_fixture()
      {:ok, _} = Content.add_word_to_lesson(lesson.id, word_with_kanji.id, %{position: 100})

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word_with_reading.id, %{position: 0})

      Enum.with_index(image_words, 1)
      |> Enum.each(fn {word, i} ->
        {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: i})
      end)

      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{
        teacher: teacher,
        student: student,
        classroom: classroom,
        lesson: lesson,
        word_with_reading: word_with_reading,
        image_word: image_word,
        image_words: image_words,
        word_with_kanji: word_with_kanji
      }
    end

    test "student earns stroke_count minus wrong_strokes on a kanji drawing test", %{
      conn: conn,
      student: student,
      classroom: classroom,
      lesson: lesson,
      teacher: teacher
    } do
      stroke_data = %{"strokes" => [%{"path" => "M 10 10 L 20 20"}]}

      word =
        word_with_kanji_fixture(
          %{stroke_count: 5, stroke_data: stroke_data},
          %{text: "明", meaning: "bright", reading: "あか"}
        )

      [entry1, entry2] =
        word.word_kanjis
        |> Enum.map(fn wk ->
          %{
            kanji_id: wk.kanji_id,
            kanji: wk.kanji,
            word: word,
            word_kanji: wk,
            kanji_reading_in_word: wk.kanji_reading
          }
        end)

      {:ok, kanji2} =
        Content.update_kanji(entry2.kanji, %{
          stroke_count: 3,
          stroke_data: stroke_data
        })

      entry2 = %{entry2 | kanji: kanji2}

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 200})

      {:ok, test} =
        ClassroomKanjiDrawingTestGenerator.generate_test(
          classroom,
          [entry1, entry2],
          teacher.id,
          title: "Kanji Drawing"
        )

      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      assert html =~ "Wrong strokes"
      assert html =~ "This kanji"
      assert html =~ "Challenge"

      [step1, step2] =
        test
        |> Medoru.Repo.preload(:test_steps)
        |> Map.get(:test_steps)
        |> Enum.sort_by(& &1.order_index)

      view
      |> element("#writing-component-#{step1.id}")
      |> render_hook("wrong_stroke", %{"count" => 2})

      html = render(view)
      parsed = Floki.parse_document!(html)

      step1_current = max(0, step1.points - 2)

      assert Floki.find(parsed, "#kanji-wrong-stroke-count-#{step1.id}") |> Floki.text() =~ "2"

      assert Floki.find(parsed, "#kanji-current-points-#{step1.id}") |> Floki.text() =~
               "#{step1_current} / #{step1.points}"

      # Challenge only counts finished kanji, so it stays at 0 while drawing.
      assert Floki.find(parsed, "#kanji-challenge-points-#{step1.id}") |> Floki.text() =~
               "0 / #{test.total_points}"

      view
      |> element("#writing-component-#{step1.id}")
      |> render_hook("kanji_complete", %{"wrong_strokes" => 2})

      html = render(view)
      parsed = Floki.parse_document!(html)

      # Wrong strokes reset for the next kanji; challenge shows earned points only.
      assert Floki.find(parsed, "#kanji-wrong-stroke-count-#{step2.id}") |> Floki.text() =~ "0"

      assert Floki.find(parsed, "#kanji-current-points-#{step2.id}") |> Floki.text() =~
               "#{step2.points} / #{step2.points}"

      assert Floki.find(parsed, "#kanji-challenge-points-#{step2.id}") |> Floki.text() =~
               "#{step1_current} / #{test.total_points}"

      # Ensure a measurable amount of time passes so the elapsed-time
      # calculation for untimed kanji drawing tests is non-zero.
      Process.sleep(1100)

      view
      |> element("#writing-component-#{step2.id}")
      |> render_hook("kanji_complete", %{"wrong_strokes" => 1})

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test.id}/results")

      attempt = Classrooms.get_test_attempt(classroom.id, student.id, test.id)
      expected_score = step1_current + max(0, step2.points - 1)
      assert attempt.score == expected_score
      assert attempt.max_score == test.total_points
      assert attempt.time_spent_seconds > 0
    end

    test "student sees localized prompt for generated kanji_writing question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      word_with_kanji: word
    } do
      {:ok, test} =
        ClassroomVocabularyTestGenerator.generate_test(
          classroom,
          [word],
          classroom.teacher_id,
          step_types: [:kanji_writing],
          max_times_per_word: 1,
          total_questions: 1
        )

      conn = log_in_user(conn, student)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      refute html =~ "__MSG_WRITE_KANJI_FOR__"
      assert html =~ "Write the kanji for"
    end

    test "student sees meaning for generated word_to_reading question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      word_with_reading: word
    } do
      {:ok, test} =
        ClassroomVocabularyTestGenerator.generate_test(
          classroom,
          [word],
          classroom.teacher_id,
          step_types: [:word_to_reading],
          max_times_per_word: 1,
          total_questions: 1
        )

      conn = log_in_user(conn, student)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      assert html =~ "How do you read this word?"
      assert html =~ word.text
      assert html =~ word.meaning
    end

    test "student sees a prompt for generated word_to_meaning question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      word_with_reading: word
    } do
      {:ok, test} =
        ClassroomVocabularyTestGenerator.generate_test(
          classroom,
          [word],
          classroom.teacher_id,
          step_types: [:word_to_meaning],
          max_times_per_word: 1,
          total_questions: 1
        )

      conn = log_in_user(conn, student)

      {:ok, _view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      assert html =~ "What is the meaning of this word?"
      assert html =~ word.text
      assert html =~ word.reading
    end

    test "student can take a generated reading_text question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      word_with_reading: word
    } do
      {:ok, test} =
        ClassroomVocabularyTestGenerator.generate_test(
          classroom,
          [word],
          classroom.teacher_id,
          step_types: [:reading_text],
          max_times_per_word: 1,
          total_questions: 1
        )

      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      assert html =~ word.text
      assert html =~ "Meaning (English)"
      assert html =~ "Reading (Hiragana)"

      view
      |> form("form", %{
        meaning_answer: word.meaning,
        reading_answer: word.reading
      })
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test.id}/results")
    end

    test "student can take a generated image_to_meaning question", %{
      conn: conn,
      student: student,
      classroom: classroom,
      image_word: word,
      image_words: image_words
    } do
      {:ok, test} =
        ClassroomVocabularyTestGenerator.generate_test(
          classroom,
          image_words,
          classroom.teacher_id,
          step_types: [:image_to_meaning],
          max_times_per_word: 1,
          total_questions: 1
        )

      conn = log_in_user(conn, student)

      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      assert html =~ "/uploads/0.jpg" or html =~ "/uploads/1.jpg" or
               html =~ "/uploads/2.jpg" or html =~ "/uploads/3.jpg"

      assert html =~ "phx-click=\"select_answer\""

      view
      |> element("button[phx-click='select_answer'][phx-value-answer='#{word.meaning}']")
      |> render_click()

      view
      |> form("form")
      |> render_submit()

      assert_redirected(view, ~p"/classrooms/#{classroom.id}/tests/#{test.id}/results")
    end
  end

  describe "Anonymous featured-classroom test taking" do
    setup do
      original_featured_id = Application.get_env(:medoru, :featured_classroom_id)
      teacher = user_fixture(%{email: "anonymous_teacher@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Featured Classroom",
          teacher_id: teacher.id
        })

      test =
        test_fixture(%{
          title: "Anonymous Test",
          created_by_id: teacher.id,
          status: :published,
          time_limit_seconds: 600,
          total_points: 2
        })

      step1 =
        test_step_fixture(test, %{
          question: "Q1",
          question_type: :multichoice,
          correct_answer: "Correct",
          options: ["Correct", "Wrong1", "Wrong2", "Wrong3"],
          order_index: 0
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

      Application.put_env(:medoru, :featured_classroom_id, classroom.id)

      on_exit(fn ->
        Application.put_env(:medoru, :featured_classroom_id, original_featured_id)
      end)

      %{
        teacher: teacher,
        classroom: classroom,
        test_resource: test,
        step1: step1,
        step2: step2
      }
    end

    test "anonymous user can take a multichoice test to completion", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      {:ok, view, html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      assert html =~ test_resource.title
      assert html =~ "Question 1 of 2"

      session = get_anonymous_session(test_resource.id)

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      assert render(view) =~ "Question 2 of 2"

      view
      |> form("form", %{answer: "Right"})
      |> render_submit()

      assert_redirected(
        view,
        ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results?session_id=#{session.id}"
      )
    end

    test "anonymous results page shows results using session_id query param", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      session = get_anonymous_session(test_resource.id)

      view
      |> form("form", %{answer: "Correct"})
      |> render_submit()

      view
      |> form("form", %{answer: "WrongA"})
      |> render_submit()

      assert_redirected(
        view,
        ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results?session_id=#{session.id}"
      )

      {:ok, _results_view, html} =
        live(
          conn,
          ~p"/classrooms/#{classroom.id}/tests/#{test_resource.id}/results?session_id=#{session.id}"
        )

      assert html =~ "Test Results"
      assert html =~ test_resource.title
      assert html =~ "Correct"
      assert html =~ "Incorrect"
      assert html =~ "50%"
    end
  end
end
