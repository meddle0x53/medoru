defmodule MedoruWeb.Teacher.ClassroomLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Classrooms

  describe "Teacher classroom management" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      admin = user_fixture(%{type: "admin"})
      %{teacher: teacher, student: student, admin: admin}
    end

    test "teacher can access classroom index", %{conn: conn, teacher: teacher} do
      {:ok, view, html} = conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms")

      assert html =~ "My Classrooms"
      assert has_element?(view, "a", "Create Classroom")
    end

    test "student cannot access teacher classroom index", %{
      conn: conn,
      student: student
    } do
      # Students are redirected to dashboard with an error message
      {:error, {:redirect, %{to: "/dashboard", flash: flash}}} =
        conn |> log_in_user(student) |> live(~p"/teacher/classrooms")

      assert flash["error"] == "You must be a teacher to access this page."
    end

    test "admin can access classroom index", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/teacher/classrooms")
      assert html =~ "My Classrooms"
    end

    test "teacher can create a classroom", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms/new")

      result =
        view
        |> form("form",
          classroom: %{name: "Test Classroom", description: "Test description"}
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/teacher/classrooms/" <> _}}} = result

      # Verify classroom was created
      [classroom] = Classrooms.list_teacher_classrooms(teacher.id)
      assert classroom.name == "Test Classroom"
      assert classroom.teacher_id == teacher.id
      assert classroom.slug == "test-classroom"
      assert String.length(classroom.invite_code) == 8
    end

    test "classroom creation validates required fields", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms/new")

      html =
        view
        |> form("form", classroom: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "classroom name must be at least 3 characters", %{conn: conn, teacher: teacher} do
      {:ok, view, _html} = conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms/new")

      html =
        view
        |> form("form", classroom: %{name: "AB"})
        |> render_submit()

      assert html =~ "should be at least 3 character"
    end

    test "teacher can view their classroom details", %{conn: conn, teacher: teacher} do
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
          teacher_id: teacher.id
        })

      {:ok, view, html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms/#{classroom.id}")

      assert html =~ classroom.name
      assert html =~ classroom.invite_code
      assert has_element?(view, "button", "Regenerate")
    end

    test "teacher can close their classroom", %{conn: conn, teacher: teacher} do
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
          teacher_id: teacher.id
        })

      {:ok, view, _html} =
        conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms/#{classroom.id}")

      view
      |> element("button", "Close")
      |> render_click()

      # Verify classroom is closed
      closed = Classrooms.get_classroom!(classroom.id)
      assert closed.status == :closed
    end

    test "teacher cannot view another teacher's classroom", %{conn: conn} do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
          teacher_id: teacher1.id
        })

      # teacher2 tries to access teacher1's classroom
      {:error, {:live_redirect, %{to: "/teacher/classrooms", flash: flash}}} =
        conn |> log_in_user(teacher2) |> live(~p"/teacher/classrooms/#{classroom.id}")

      assert flash["error"] == "You don't have permission to access this classroom."
    end

    test "archived classrooms don't appear in list", %{conn: conn, teacher: teacher} do
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
          teacher_id: teacher.id
        })

      {:ok, _} = Classrooms.archive_classroom(classroom)

      {:ok, _view, html} = conn |> log_in_user(teacher) |> live(~p"/teacher/classrooms")

      refute html =~ classroom.name
      assert html =~ "No classrooms yet"
    end
  end
end
