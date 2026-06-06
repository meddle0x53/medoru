defmodule MedoruWeb.ClassroomLive.IndexTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Classrooms

  describe "Classroom Index - Mount & Render" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      %{conn: conn, student: student}
    end

    test "renders classroom index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/classrooms")

      assert html =~ "Classrooms"
      assert html =~ "Browse public classrooms or join one with an invite code"
    end

    test "shows owned count for teachers", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, _view, html} = live(conn, ~p"/classrooms")
      assert html =~ "Owned"
    end

    test "does not show owned count for students", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/classrooms")
      refute html =~ "Owned"
    end

    test "shows empty state when no classrooms", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/classrooms")
      assert html =~ "No classrooms found"
    end

    test "lists public classrooms", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Public Classroom",
          description: "A public classroom",
          teacher_id: teacher.id,
          public: true
        })

      {:ok, _view, html} = live(conn, ~p"/classrooms")
      assert html =~ classroom.name
      assert html =~ "Public"
    end

    test "lists owned classrooms for teachers", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "My Classroom",
          description: "My classroom",
          teacher_id: teacher.id
        })

      {:ok, _view, html} = live(conn, ~p"/classrooms")
      assert html =~ classroom.name
      assert html =~ "Owner"
    end

    test "shows pending applications", %{conn: conn, student: student} do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Approval Classroom",
          description: "Needs approval",
          teacher_id: teacher.id,
          should_approve_memberships: true
        })

      {:ok, _membership} = Classrooms.apply_to_join(classroom.id, student.id)

      {:ok, _view, html} = live(conn, ~p"/classrooms")
      assert html =~ "Pending Applications"
      assert html =~ classroom.name
      assert html =~ "Cancel this application?"
    end
  end

  describe "Classroom Index - Search" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      %{conn: conn, student: student}
    end

    test "search filters public classrooms", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, _classroom} =
        Classrooms.create_classroom(%{
          name: "Searchable Classroom",
          description: "A public classroom",
          teacher_id: teacher.id,
          public: true
        })

      {:ok, view, _html} = live(conn, ~p"/classrooms")

      # Search for the classroom
      view
      |> form("form[phx-change='search']", %{search: "Searchable"})
      |> render_change()

      # Should redirect with search param
      assert_patch(view, ~p"/classrooms?search=Searchable")
    end

    test "search with no results shows empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-change='search']", %{search: "nonexistent"})
      |> render_change()

      html = render(view)
      assert html =~ "No classrooms found"
      assert html =~ "No classrooms match your search"
    end
  end

  describe "Classroom Index - Invite Code Validation" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Code Classroom",
          description: "A test classroom",
          teacher_id: teacher.id
        })

      %{conn: conn, student: student, classroom: classroom}
    end

    test "validates correct invite code", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-change='validate_code']", %{invite_code: classroom.invite_code})
      |> render_change()

      html = render(view)
      assert html =~ classroom.name
    end

    test "shows error for invalid invite code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-change='validate_code']", %{invite_code: "INVALID"})
      |> render_change()

      html = render(view)
      assert html =~ "Invalid invite code"
    end

    test "shows error for already member", %{conn: conn, student: student, classroom: classroom} do
      # Join the classroom first
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-change='validate_code']", %{invite_code: classroom.invite_code})
      |> render_change()

      html = render(view)
      assert html =~ "You are already a member of this classroom"
    end

    test "shows error for closed classroom", %{conn: conn, classroom: classroom} do
      {:ok, _} = Classrooms.close_classroom(classroom)

      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-change='validate_code']", %{invite_code: classroom.invite_code})
      |> render_change()

      html = render(view)
      # Closed classrooms may be filtered out by get_classroom_by_invite_code
      # or may show "not accepting new members"
      assert html =~ "Invalid invite code" or html =~ "not accepting new members"
    end
  end

  describe "Classroom Index - Join via Invite Code" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Join Classroom",
          description: "A test classroom",
          teacher_id: teacher.id,
          should_approve_memberships: false
        })

      %{conn: conn, student: student, classroom: classroom}
    end

    test "joins classroom with auto-approve", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> form("form[phx-submit='join']", %{invite_code: classroom.invite_code})
      |> render_submit()

      assert_patch(view, ~p"/classrooms")
    end

    test "shows error for invalid code on join", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      html =
        view
        |> form("form[phx-submit='join']", %{invite_code: "INVALID"})
        |> render_submit()

      assert html =~ "Invalid invite code"
    end

    test "shows already_member error on join", %{conn: conn, student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, view, _html} = live(conn, ~p"/classrooms")

      html =
        view
        |> form("form[phx-submit='join']", %{invite_code: classroom.invite_code})
        |> render_submit()

      assert html =~ "You are already a member of this classroom"
    end
  end

  describe "Classroom Index - Join Public Classroom" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Public Join Classroom",
          description: "A public classroom",
          teacher_id: teacher.id,
          public: true,
          should_approve_memberships: false
        })

      %{conn: conn, student: student, classroom: classroom}
    end

    test "joins public classroom", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> element("button[phx-click='join_public']")
      |> render_click(%{"id" => classroom.id})

      assert_patch(view, ~p"/classrooms")
    end

    test "shows error when already member of public classroom", %{
      conn: conn,
      student: student,
      classroom: classroom
    } do
      # Join first
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, view, _html} = live(conn, ~p"/classrooms")

      # Button won't be shown since already a member, trigger event directly
      render_click(view, "join_public", %{"id" => classroom.id})

      assert render(view) =~ "You are already a member of this classroom"
    end
  end

  describe "Classroom Index - Cancel Application" do
    setup %{conn: conn} do
      student = user_fixture(%{type: "student"})
      conn = log_in_user(conn, student)
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Cancel Classroom",
          description: "A test classroom",
          teacher_id: teacher.id,
          should_approve_memberships: true
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)

      %{conn: conn, student: student, classroom: classroom, membership: membership}
    end

    test "cancels pending application", %{conn: conn, membership: membership} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> element("button[phx-click='cancel_application'][phx-value-id='#{membership.id}']")
      |> render_click()

      assert_patch(view, ~p"/classrooms")
      refute Medoru.Repo.get(Medoru.Classrooms.ClassroomMembership, membership.id)
    end

    test "shows error for non-existent application", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/classrooms")

      view
      |> element("button[phx-click='cancel_application']")
      |> render_click(%{"id" => Ecto.UUID.generate()})

      assert render(view) =~ "Application not found"
    end
  end
end
