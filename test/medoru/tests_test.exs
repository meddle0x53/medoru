defmodule Medoru.TestsTest do
  use Medoru.DataCase

  alias Medoru.Tests
  alias Medoru.Tests.{Test, TestStep, TestSession, TestStepAnswer}

  describe "tests" do
    @valid_attrs %{
      title: "N5 Daily Review",
      description: "Test your N5 vocabulary",
      test_type: :daily,
      status: :draft,
      time_limit_seconds: 300,
      is_system: true
    }
    @update_attrs %{
      title: "Updated Title",
      description: "Updated description",
      status: :ready
    }
    @invalid_attrs %{title: nil, test_type: nil}

    def test_fixture(attrs \\ %{}) do
      {:ok, test} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Tests.create_test()

      test
    end

    test "list_tests/0 returns all tests" do
      test = test_fixture()
      [listed] = Tests.list_tests()
      assert listed.id == test.id
      assert listed.title == test.title
    end

    test "list_tests/1 filters by type" do
      test_fixture(%{test_type: :daily})
      test_fixture(%{test_type: :lesson})

      assert length(Tests.list_tests(type: :daily)) == 1
      assert length(Tests.list_tests(type: :lesson)) == 1
    end

    test "list_tests/1 filters by status" do
      test_fixture(%{status: :draft})
      test_fixture(%{status: :published})

      assert length(Tests.list_tests(status: :draft)) == 1
      assert length(Tests.list_tests(status: :published)) == 1
    end

    test "get_test!/1 returns the test with given id" do
      test = test_fixture()
      fetched = Tests.get_test!(test.id)
      assert fetched.id == test.id
      assert fetched.title == test.title
    end

    test "create_test/1 with valid data creates a test" do
      assert {:ok, %Test{} = test} = Tests.create_test(@valid_attrs)
      assert test.title == "N5 Daily Review"
      assert test.test_type == :daily
      assert test.status == :draft
      assert test.total_points == 0
      assert test.is_system == true
    end

    test "create_test/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tests.create_test(@invalid_attrs)
    end

    test "create_test/1 with nil max_attempts is valid" do
      # Bug fix: max_attempts can be nil (unlimited attempts)
      attrs = Map.put(@valid_attrs, :max_attempts, nil)
      assert {:ok, %Test{} = test} = Tests.create_test(attrs)
      assert test.max_attempts == nil
    end

    test "create_test/1 with valid max_attempts is valid" do
      attrs = Map.put(@valid_attrs, :max_attempts, 5)
      assert {:ok, %Test{} = test} = Tests.create_test(attrs)
      assert test.max_attempts == 5
    end

    test "create_test/1 with invalid max_attempts returns error" do
      attrs = Map.put(@valid_attrs, :max_attempts, 15)
      assert {:error, %Ecto.Changeset{errors: errors}} = Tests.create_test(attrs)
      assert errors[:max_attempts]
    end

    test "update_test/2 with valid data updates the test" do
      test = test_fixture()
      assert {:ok, %Test{} = test} = Tests.update_test(test, @update_attrs)
      assert test.title == "Updated Title"
      assert test.status == :ready
    end

    test "update_test/2 with invalid data returns error changeset" do
      test = test_fixture()
      assert {:error, %Ecto.Changeset{}} = Tests.update_test(test, @invalid_attrs)
      # Verify test was not modified
      reloaded = Tests.get_test!(test.id)
      assert reloaded.title == test.title
      assert reloaded.id == test.id
    end

    test "delete_test/1 deletes the test" do
      test = test_fixture()
      assert {:ok, %Test{}} = Tests.delete_test(test)
      assert_raise Ecto.NoResultsError, fn -> Tests.get_test!(test.id) end
    end

    test "change_test/1 returns a test changeset" do
      test = test_fixture()
      assert %Ecto.Changeset{} = Tests.change_test(test)
    end

    test "publish_test/1 publishes a test" do
      test = test_fixture()
      assert {:ok, %Test{status: :published}} = Tests.publish_test(test)
    end

    test "archive_test/1 archives a test" do
      test = test_fixture()
      assert {:ok, %Test{status: :archived}} = Tests.archive_test(test)
    end
  end

  describe "test_steps" do
    @valid_step_attrs %{
      order_index: 0,
      step_type: :vocabulary,
      question_type: :multichoice,
      question: "What does 日本 mean?",
      correct_answer: "Japan",
      options: ["Japan", "China", "Korea", "Vietnam"],
      points: 1
    }

    @valid_fill_attrs %{
      order_index: 1,
      step_type: :writing,
      question_type: :fill,
      question: "Fill in: 日本＿",
      correct_answer: "語",
      points: 2
    }

    setup do
      {:ok, test_record} = Tests.create_test(%{title: "Test", test_type: :daily})
      %{test_record: test_record}
    end

    test "list_test_steps/1 returns all steps for a test", %{test_record: test_record} do
      {:ok, _step} = Tests.create_test_step(test_record, @valid_step_attrs)
      steps = Tests.list_test_steps(test_record.id)
      assert length(steps) == 1
      assert hd(steps).question == "What does 日本 mean?"
    end

    test "get_test_step/1 returns the step with given id", %{test_record: test_record} do
      {:ok, step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert Tests.get_test_step(step.id) == step
    end

    test "get_test_step_by_index/2 returns step by index", %{test_record: test_record} do
      {:ok, step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert Tests.get_test_step_by_index(test_record.id, 0).id == step.id
    end

    test "create_test_step/2 with valid data creates a step", %{test_record: test_record} do
      assert {:ok, %TestStep{} = step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert step.question == "What does 日本 mean?"
      assert step.points == 1

      # Total points should be updated
      updated_test = Tests.get_test!(test_record.id)
      assert updated_test.total_points == 1
    end

    test "create_test_step/2 validates multichoice has options", %{test_record: test_record} do
      attrs = %{@valid_step_attrs | options: []}
      assert {:error, %Ecto.Changeset{}} = Tests.create_test_step(test_record, attrs)
    end

    test "create_test_step/2 validates points match question type", %{test_record: test_record} do
      # Multichoice should be 1 point
      attrs = %{@valid_step_attrs | points: 2}
      assert {:error, %Ecto.Changeset{}} = Tests.create_test_step(test_record, attrs)

      # Fill should be 1 or 2 points
      attrs = %{@valid_fill_attrs | points: 3}
      assert {:error, %Ecto.Changeset{}} = Tests.create_test_step(test_record, attrs)
    end

    test "create_test_steps/2 creates multiple steps", %{test_record: test_record} do
      steps = [@valid_step_attrs, @valid_fill_attrs]
      assert {:ok, created_steps} = Tests.create_test_steps(test_record, steps)
      assert length(created_steps) == 2

      # Total points should be sum of all steps
      updated_test = Tests.get_test!(test_record.id)
      assert updated_test.total_points == 3
    end

    test "update_test_step/2 with valid data updates the step", %{test_record: test_record} do
      {:ok, step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert {:ok, %TestStep{} = step} = Tests.update_test_step(step, %{question: "Updated"})
      assert step.question == "Updated"
    end

    test "delete_test_step/1 deletes the step", %{test_record: test_record} do
      {:ok, step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert {:ok, %TestStep{}} = Tests.delete_test_step(step)
      assert Tests.get_test_step(step.id) == nil
    end

    test "change_test_step/1 returns a step changeset", %{test_record: test_record} do
      {:ok, step} = Tests.create_test_step(test_record, @valid_step_attrs)
      assert %Ecto.Changeset{} = Tests.change_test_step(step)
    end
  end

  describe "test_sessions" do
    setup do
      {:ok, test_record} = Tests.create_test(%{title: "Test", test_type: :daily})

      {:ok, _step} =
        Tests.create_test_step(test_record, %{
          order_index: 0,
          step_type: :vocabulary,
          question_type: :multichoice,
          question: "What does 日本 mean?",
          correct_answer: "Japan",
          options: ["Japan", "China", "Korea", "Vietnam"],
          points: 1
        })

      user = user_fixture()
      %{test_record: test_record, user: user}
    end

    defp user_fixture do
      email = "test#{System.unique_integer()}@example.com"

      {:ok, user} =
        Medoru.Accounts.register_user_with_oauth(%{
          email: email,
          provider: "google",
          provider_uid: "uid_#{System.unique_integer()}"
        })

      user
    end

    test "list_test_sessions/1 returns all sessions for a user", %{
      test_record: test_record,
      user: user
    } do
      {:ok, _session} = Tests.start_test_session(user.id, test_record.id)
      sessions = Tests.list_test_sessions(user.id)
      assert length(sessions) == 1
    end

    test "get_test_session/1 returns the session", %{test_record: test_record, user: user} do
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)
      assert Tests.get_test_session(session.id) == session
    end

    test "start_test_session/2 creates a new session", %{test_record: test_record, user: user} do
      assert {:ok, %TestSession{} = session} = Tests.start_test_session(user.id, test_record.id)
      assert session.user_id == user.id
      assert session.test_id == test_record.id
      assert session.status == :started
      assert session.current_step_index == 0
      assert session.score == 0
    end

    test "start_test_session/2 returns existing active session", %{
      test_record: test_record,
      user: user
    } do
      {:ok, session1} = Tests.start_test_session(user.id, test_record.id)
      {:ok, session2} = Tests.start_test_session(user.id, test_record.id)
      assert session1.id == session2.id
    end

    test "has_active_session?/2 checks for active sessions", %{
      test_record: test_record,
      user: user
    } do
      assert not Tests.has_active_session?(user.id, test_record.id)
      {:ok, _session} = Tests.start_test_session(user.id, test_record.id)
      assert Tests.has_active_session?(user.id, test_record.id)
    end

    test "progress_session/3 updates session progress", %{test_record: test_record, user: user} do
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)
      assert {:ok, %TestSession{} = session} = Tests.progress_session(session, 3, 120)
      assert session.current_step_index == 3
      assert session.time_spent_seconds == 120
      assert session.status == :in_progress
    end

    test "complete_session/4 completes a session", %{test_record: test_record, user: user} do
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)
      assert {:ok, %TestSession{} = session} = Tests.complete_session(session, 85, 100, 300)
      assert session.status == :completed
      assert session.score == 85
      assert session.percentage == 85.0
    end

    test "abandon_session/2 abandons a session", %{test_record: test_record, user: user} do
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)
      assert {:ok, %TestSession{} = session} = Tests.abandon_session(session, 180)
      assert session.status == :abandoned
    end

    test "timeout_session/4 times out a session", %{test_record: test_record, user: user} do
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)
      assert {:ok, %TestSession{} = session} = Tests.timeout_session(session, 45, 100, 600)
      assert session.status == :timed_out
      assert session.score == 45
    end
  end

  describe "test_step_answers" do
    setup do
      {:ok, test_record} = Tests.create_test(%{title: "Test", test_type: :daily})

      {:ok, step} =
        Tests.create_test_step(test_record, %{
          order_index: 0,
          step_type: :vocabulary,
          question_type: :multichoice,
          question: "What does 日本 mean?",
          correct_answer: "Japan",
          options: ["Japan", "China", "Korea", "Vietnam"],
          points: 1
        })

      user = user_fixture()
      {:ok, session} = Tests.start_test_session(user.id, test_record.id)

      %{test_record: test_record, step: step, user: user, session: session}
    end

    defp user_fixture do
      email = "test#{System.unique_integer()}@example.com"

      {:ok, user} =
        Medoru.Accounts.register_user_with_oauth(%{
          email: email,
          provider: "google",
          provider_uid: "uid_#{System.unique_integer()}"
        })

      user
    end

    test "record_step_answer/3 records a correct answer", %{step: step, session: session} do
      attrs = %{"answer" => "Japan", "time_spent_seconds" => 30, "step_index" => 0}

      assert {:ok, %TestStepAnswer{} = answer} =
               Tests.record_step_answer(session.id, step.id, attrs)

      assert answer.is_correct == true
      assert answer.points_earned == 1
    end

    test "record_step_answer/3 records an incorrect answer", %{step: step, session: session} do
      attrs = %{"answer" => "China", "time_spent_seconds" => 30, "step_index" => 0}

      assert {:ok, %TestStepAnswer{} = answer} =
               Tests.record_step_answer(session.id, step.id, attrs)

      assert answer.is_correct == false
      assert answer.points_earned == 0
    end

    test "record_step_answer/3 applies penalties for hints", %{step: step, session: session} do
      attrs = %{
        "answer" => "Japan",
        "time_spent_seconds" => 30,
        "step_index" => 0,
        "hints_used" => 1
      }

      assert {:ok, %TestStepAnswer{} = answer} =
               Tests.record_step_answer(session.id, step.id, attrs)

      # 1 hint = 10% penalty, so 0.9 points rounded to 1 (minimum)
      assert answer.points_earned == 1
    end

    test "list_step_answers/1 returns all answers for a session", %{step: step, session: session} do
      attrs = %{"answer" => "Japan", "time_spent_seconds" => 30, "step_index" => 0}
      {:ok, _} = Tests.record_step_answer(session.id, step.id, attrs)

      answers = Tests.list_step_answers(session.id)
      assert length(answers) == 1
    end

    test "calculate_session_score/1 calculates total score", %{step: step, session: session} do
      attrs = %{"answer" => "Japan", "time_spent_seconds" => 30, "step_index" => 0}
      {:ok, _} = Tests.record_step_answer(session.id, step.id, attrs)

      {score, total} = Tests.calculate_session_score(session.id)
      assert score == 1
      assert total == 1
    end
  end

  describe "statistics" do
    setup do
      {:ok, test_record} = Tests.create_test(%{title: "Test", test_type: :daily})

      {:ok, _step} =
        Tests.create_test_step(test_record, %{
          order_index: 0,
          step_type: :vocabulary,
          question_type: :multichoice,
          question: "What does 日本 mean?",
          correct_answer: "Japan",
          options: ["Japan", "China", "Korea", "Vietnam"],
          points: 1
        })

      user = user_fixture()
      %{test_record: test_record, user: user}
    end

    defp user_fixture do
      email = "test#{System.unique_integer()}@example.com"

      {:ok, user} =
        Medoru.Accounts.register_user_with_oauth(%{
          email: email,
          provider: "google",
          provider_uid: "uid_#{System.unique_integer()}"
        })

      user
    end

    test "get_user_test_stats/1 returns user statistics", %{test_record: test_record, user: user} do
      # Create some sessions
      {:ok, session1} = Tests.start_test_session(user.id, test_record.id)
      Tests.complete_session(session1, 80, 100, 300)

      {:ok, session2} = Tests.start_test_session(user.id, test_record.id)
      Tests.abandon_session(session2, 180)

      stats = Tests.get_user_test_stats(user.id)
      assert stats.total_tests_taken == 2
      assert stats.tests_completed == 1
      assert stats.tests_abandoned == 1
      assert stats.average_score == 80.0
    end

    test "get_test_stats/1 returns test statistics", %{test_record: test_record, user: user} do
      # Create sessions from multiple users
      user2 = user_fixture()

      {:ok, session1} = Tests.start_test_session(user.id, test_record.id)
      Tests.complete_session(session1, 75, 100, 300)

      {:ok, session2} = Tests.start_test_session(user2.id, test_record.id)
      Tests.complete_session(session2, 85, 100, 400)

      stats = Tests.get_test_stats(test_record.id)
      assert stats.total_sessions == 2
      assert stats.completion_rate == 100.0
      assert stats.average_score == 80.0
    end
  end

  describe "teacher tests" do
    defp teacher_fixture do
      email = "teacher#{System.unique_integer()}@example.com"

      {:ok, user} =
        Medoru.Accounts.register_user_with_oauth(%{
          email: email,
          provider: "google",
          provider_uid: "uid_#{System.unique_integer()}"
        })

      user
    end

    test "create_teacher_test/2 creates a teacher test with string keys (form params)" do
      teacher = teacher_fixture()

      # Use string keys to simulate form params
      attrs = %{
        "title" => "My Quiz",
        "description" => "Test description",
        "time_limit_seconds" => "600",
        "max_attempts" => "3"
      }

      assert {:ok, %Test{} = test} = Tests.create_teacher_test(attrs, teacher.id)
      assert test.title == "My Quiz"
      assert test.description == "Test description"
      assert test.time_limit_seconds == 600
      assert test.max_attempts == 3
      assert test.test_type == :teacher
      assert test.setup_state == "in_progress"
      assert test.creator_id == teacher.id
    end

    test "create_teacher_test/2 with atom keys also works" do
      teacher = teacher_fixture()

      attrs = %{
        title: "My Quiz 2",
        description: "Another test"
      }

      assert {:ok, %Test{} = test} = Tests.create_teacher_test(attrs, teacher.id)
      assert test.title == "My Quiz 2"
      assert test.test_type == :teacher
    end

    test "create_teacher_test/2 with nil max_attempts" do
      teacher = teacher_fixture()

      attrs = %{
        "title" => "Unlimited Quiz",
        "max_attempts" => nil
      }

      assert {:ok, %Test{} = test} = Tests.create_teacher_test(attrs, teacher.id)
      assert test.max_attempts == nil
    end

    test "list_teacher_tests/2 returns tests for a teacher" do
      teacher = teacher_fixture()
      other_teacher = teacher_fixture()

      {:ok, test1} =
        Tests.create_teacher_test(%{"title" => "Quiz 1"}, teacher.id)

      {:ok, test2} =
        Tests.create_teacher_test(%{"title" => "Quiz 2"}, teacher.id)

      {:ok, _other_test} =
        Tests.create_teacher_test(%{"title" => "Other Quiz"}, other_teacher.id)

      tests = Tests.list_teacher_tests(teacher.id)
      assert length(tests) == 2
      assert Enum.map(tests, & &1.id) |> Enum.sort() == [test1.id, test2.id] |> Enum.sort()
    end

    test "list_teacher_tests/2 filters by setup_state" do
      teacher = teacher_fixture()

      {:ok, test} =
        Tests.create_teacher_test(%{"title" => "Quiz"}, teacher.id)

      # Initially in_progress
      assert Tests.list_teacher_tests(teacher.id, setup_state: "in_progress") == [test]
      assert Tests.list_teacher_tests(teacher.id, setup_state: "ready") == []

      # Mark as ready
      {:ok, test} = Tests.mark_test_ready(test)
      [listed] = Tests.list_teacher_tests(teacher.id, setup_state: "ready")
      assert listed.id == test.id
    end
  end
end
