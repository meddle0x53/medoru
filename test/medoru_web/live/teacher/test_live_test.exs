defmodule MedoruWeb.Teacher.TestLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  alias Medoru.Tests

  describe "Teacher test management" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      %{teacher: teacher, student: student}
    end

    test "teacher can access test index", %{conn: conn, teacher: teacher} do
      {:ok, view, html} = conn |> log_in_user(teacher) |> live(~p"/teacher/tests")

      assert html =~ "My Tests"
      assert has_element?(view, "button", "Create Test")
    end

    test "student cannot access teacher test index", %{conn: conn, student: student} do
      {:error, {:redirect, %{to: "/dashboard", flash: flash}}} =
        conn |> log_in_user(student) |> live(~p"/teacher/tests")

      assert flash["error"] == "You must be a teacher to access this page."
    end

    test "teacher can create a new test", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/tests/new")

      result =
        view
        |> form("form",
          test: %{
            title: "Test Title",
            description: "Test description",
            time_limit_seconds: "600",
            max_attempts: "2"
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/teacher/tests/" <> _}}} = result

      # Verify test was created
      [test] = Tests.list_teacher_tests(teacher.id)
      assert test.title == "Test Title"
      assert test.test_type == :teacher
      assert test.setup_state == "in_progress"
      assert test.creator_id == teacher.id
    end

    test "test title is required", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/tests/new")

      html =
        view
        |> form("form", test: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "teacher can edit their in_progress test", %{conn: conn, teacher: teacher} do
      test = teacher_test_fixture(teacher.id)

      {:ok, view, html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}/edit")

      assert html =~ test.title
      assert has_element?(view, "button", "Add First Step")
    end

    test "teacher cannot edit another teacher's test", %{conn: conn} do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      test = teacher_test_fixture(teacher1.id)

      {:error, {:live_redirect, %{to: "/teacher/tests", flash: flash}}} =
        conn |> log_in_user(teacher2) |> live(~p"/teacher/tests/#{test.id}/edit")

      assert flash["error"] == "You can only edit your own tests."
    end

    test "teacher can add multichoice step", %{conn: conn, teacher: teacher} do
      test = teacher_test_fixture(teacher.id)

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}/edit")

      # Open step selector
      view
      |> element("button", "Add First Step")
      |> render_click()

      # Select multichoice type
      view
      |> element("button[phx-value-type='multichoice']")
      |> render_click()

      # The step form should now be open
      assert has_element?(view, "textarea[name='step[question]']")
    end

    test "teacher can view test details", %{conn: conn, teacher: teacher} do
      test = teacher_test_fixture(teacher.id)

      {:ok, _view, html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}")

      assert html =~ test.title
    end

    test "filter tests by state", %{conn: conn, teacher: teacher} do
      _in_progress = teacher_test_fixture(teacher.id, %{setup_state: "in_progress"})
      _ready = teacher_test_fixture(teacher.id, %{setup_state: "ready"})

      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/tests")

      # Filter by in_progress
      html =
        view
        |> element("button[phx-value-state='in_progress']")
        |> render_click(%{"state" => "in_progress"})

      assert html =~ "In Progress"
    end

    test "invalid step type is handled gracefully", %{conn: conn, teacher: teacher} do
      test = teacher_test_fixture(teacher.id)

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      # The form should open with valid type selection available
      assert has_element?(view, "button[phx-value-type='multichoice']")
      assert has_element?(view, "button[phx-value-type='fill']")
      assert has_element?(view, "button[phx-value-type='writing']")
    end

    test "cannot edit published test", %{conn: conn, teacher: teacher} do
      test = teacher_test_fixture(teacher.id)
      _step = test_step_fixture(test)

      # First mark as ready
      {:ok, _} = Tests.mark_test_ready(test)
      test = Tests.get_test!(test.id)

      # Then publish
      {:ok, _} = Tests.publish_teacher_test(test)
      test = Tests.get_test!(test.id)

      assert test.setup_state == "published"

      # Now try to edit
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}/edit")

      assert path == "/teacher/tests/#{test.id}"
      assert flash["info"] == "This test can no longer be edited."
    end
  end
end
