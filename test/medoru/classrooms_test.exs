defmodule Medoru.ClassroomsTest do
  use Medoru.DataCase

  alias Medoru.Classrooms
  alias Medoru.Classrooms.{Classroom, ClassroomMembership}

  import Medoru.AccountsFixtures

  describe "classrooms" do
    @valid_attrs %{name: "Test Classroom", description: "A test classroom"}
    @update_attrs %{name: "Updated Name", description: "Updated description"}
    @invalid_attrs %{name: ""}

    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      {:ok, teacher: teacher, student: student}
    end

    test "list_teacher_classrooms/1 returns all classrooms for a teacher", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      [listed_classroom] = Classrooms.list_teacher_classrooms(teacher.id)
      assert listed_classroom.id == classroom.id
      assert listed_classroom.name == classroom.name
    end

    test "list_teacher_classrooms/1 excludes archived classrooms", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      {:ok, _} = Classrooms.archive_classroom(classroom)
      assert Classrooms.list_teacher_classrooms(teacher.id) == []
    end

    test "get_classroom!/1 returns the classroom with given id", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert Classrooms.get_classroom!(classroom.id).id == classroom.id
    end

    test "get_classroom_by_slug/1 returns the classroom with given slug", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert Classrooms.get_classroom_by_slug(classroom.slug).id == classroom.id
    end

    test "get_classroom_by_invite_code/1 returns the classroom with given code", %{
      teacher: teacher
    } do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert Classrooms.get_classroom_by_invite_code(classroom.invite_code).id == classroom.id
    end

    test "create_classroom/1 with valid data creates a classroom", %{teacher: teacher} do
      attrs = Map.merge(@valid_attrs, %{teacher_id: teacher.id})
      assert {:ok, %Classroom{} = classroom} = Classrooms.create_classroom(attrs)
      assert classroom.name == "Test Classroom"
      assert classroom.description == "A test classroom"
      assert classroom.teacher_id == teacher.id
      assert classroom.status == :active
      assert classroom.slug != nil
      assert classroom.invite_code != nil
    end

    test "create_classroom/1 auto-generates slug from name", %{teacher: teacher} do
      attrs = %{name: "My Test Classroom", teacher_id: teacher.id}
      assert {:ok, %Classroom{} = classroom} = Classrooms.create_classroom(attrs)
      assert classroom.slug == "my-test-classroom"
    end

    test "create_classroom/1 auto-generates invite code", %{teacher: teacher} do
      attrs = Map.merge(@valid_attrs, %{teacher_id: teacher.id})
      assert {:ok, %Classroom{} = classroom} = Classrooms.create_classroom(attrs)
      assert String.length(classroom.invite_code) == 8
    end

    test "create_classroom/1 with invalid data returns error changeset", %{teacher: teacher} do
      attrs = Map.merge(@invalid_attrs, %{teacher_id: teacher.id})
      assert {:error, %Ecto.Changeset{}} = Classrooms.create_classroom(attrs)
    end

    test "update_classroom/2 with valid data updates the classroom", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})

      assert {:ok, %Classroom{} = classroom} =
               Classrooms.update_classroom(classroom, @update_attrs)

      assert classroom.name == "Updated Name"
      assert classroom.description == "Updated description"
    end

    test "update_classroom/2 with invalid data returns error changeset", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert {:error, %Ecto.Changeset{}} = Classrooms.update_classroom(classroom, @invalid_attrs)
    end

    test "archive_classroom/1 sets status to archived", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert {:ok, %Classroom{} = classroom} = Classrooms.archive_classroom(classroom)
      assert classroom.status == :archived
    end

    test "close_classroom/1 sets status to closed", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert {:ok, %Classroom{} = classroom} = Classrooms.close_classroom(classroom)
      assert classroom.status == :closed
    end

    test "regenerate_invite_code/1 generates a new invite code", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      old_code = classroom.invite_code
      assert {:ok, %Classroom{} = classroom} = Classrooms.regenerate_invite_code(classroom)
      assert classroom.invite_code != old_code
      assert String.length(classroom.invite_code) == 8
    end

    test "change_classroom/1 returns a classroom changeset", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      assert %Ecto.Changeset{} = Classrooms.change_classroom(classroom)
    end
  end

  describe "classroom memberships" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      {:ok, teacher: teacher, student: student, classroom: classroom}
    end

    test "apply_to_join/2 creates a pending membership", %{student: student, classroom: classroom} do
      assert {:ok, %ClassroomMembership{} = membership} =
               Classrooms.apply_to_join(classroom.id, student.id)

      assert membership.status == :pending
      assert membership.role == :student
      assert membership.classroom_id == classroom.id
      assert membership.user_id == student.id
    end

    test "apply_to_join/2 returns error if already a member", %{
      student: student,
      classroom: classroom
    } do
      # First application
      assert {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      # Second application should fail
      assert {:error, :already_member} = Classrooms.apply_to_join(classroom.id, student.id)
    end

    test "approve_membership/1 approves a pending membership", %{
      student: student,
      classroom: classroom
    } do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)

      assert {:ok, %ClassroomMembership{} = membership} =
               Classrooms.approve_membership(membership)

      assert membership.status == :approved
      assert membership.joined_at != nil
    end

    test "reject_membership/1 rejects a pending membership", %{
      student: student,
      classroom: classroom
    } do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      assert {:ok, %ClassroomMembership{} = membership} = Classrooms.reject_membership(membership)
      assert membership.status == :rejected
    end

    test "remove_member/1 removes an approved member", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, membership} = Classrooms.approve_membership(membership)
      assert {:ok, %ClassroomMembership{} = membership} = Classrooms.remove_member(membership)
      assert membership.status == :removed
    end

    test "leave_classroom/1 marks membership as left", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, membership} = Classrooms.approve_membership(membership)
      assert {:ok, %ClassroomMembership{} = membership} = Classrooms.leave_classroom(membership)
      assert membership.status == :left
    end

    test "is_member?/2 returns true for pending or approved members", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.is_member?(classroom.id, student.id) == false
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      assert Classrooms.is_member?(classroom.id, student.id) == true
    end

    test "is_approved_member?/2 returns true only for approved members", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.is_approved_member?(classroom.id, student.id) == false
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      assert Classrooms.is_approved_member?(classroom.id, student.id) == false
      {:ok, _} = Classrooms.approve_membership(membership)
      assert Classrooms.is_approved_member?(classroom.id, student.id) == true
    end

    test "list_classroom_members/1 returns approved members", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.list_classroom_members(classroom.id) == []
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      assert Classrooms.list_classroom_members(classroom.id) == []
      {:ok, _} = Classrooms.approve_membership(membership)
      assert length(Classrooms.list_classroom_members(classroom.id)) == 1
    end

    test "list_pending_memberships/1 returns pending applications", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.list_pending_memberships(classroom.id) == []
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      assert length(Classrooms.list_pending_memberships(classroom.id)) == 1
    end

    test "update_member_points/2 updates member points", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, membership} = Classrooms.approve_membership(membership)

      assert {:ok, %ClassroomMembership{} = membership} =
               Classrooms.update_member_points(membership, 100)

      assert membership.points == 100
    end

    test "add_member_points/2 adds points to member", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, membership} = Classrooms.approve_membership(membership)

      assert {:ok, %ClassroomMembership{} = membership} =
               Classrooms.add_member_points(membership, 50)

      assert membership.points == 50

      assert {:ok, %ClassroomMembership{} = membership} =
               Classrooms.add_member_points(membership, 25)

      assert membership.points == 75
    end

    test "get_user_membership/2 returns membership for user in classroom", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.get_user_membership(classroom.id, student.id) == nil
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      found = Classrooms.get_user_membership(classroom.id, student.id)
      assert found.id == membership.id
    end

    test "get_classroom_stats/1 returns classroom statistics", %{
      student: student,
      classroom: classroom
    } do
      stats = Classrooms.get_classroom_stats(classroom.id)
      assert stats.total_members == 0
      assert stats.pending_applications == 0
      assert stats.total_points == 0

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      stats = Classrooms.get_classroom_stats(classroom.id)
      assert stats.pending_applications == 1

      {:ok, membership} = Classrooms.approve_membership(membership)
      {:ok, _} = Classrooms.add_member_points(membership, 100)
      stats = Classrooms.get_classroom_stats(classroom.id)
      assert stats.total_members == 1
      assert stats.total_points == 100
    end
  end

  describe "list_student_classrooms/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      {:ok, teacher: teacher, student: student, classroom: classroom}
    end

    test "returns approved classrooms for a student", %{student: student, classroom: classroom} do
      assert Classrooms.list_student_classrooms(student.id) == []
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      assert Classrooms.list_student_classrooms(student.id) == []
      {:ok, _} = Classrooms.approve_membership(membership)
      assert length(Classrooms.list_student_classrooms(student.id)) == 1
    end

    test "excludes closed or archived classrooms", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      assert length(Classrooms.list_student_classrooms(student.id)) == 1

      # Close the classroom
      {:ok, _} = Classrooms.close_classroom(classroom)
      assert Classrooms.list_student_classrooms(student.id) == []
    end
  end

  describe "delete_classroom/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, teacher: teacher}
    end

    test "deletes an archived classroom permanently", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      {:ok, archived} = Classrooms.archive_classroom(classroom)

      assert {:ok, %Classroom{}} = Classrooms.delete_classroom(archived)
      assert_raise Ecto.NoResultsError, fn -> Classrooms.get_classroom!(classroom.id) end
    end

    test "returns error when trying to delete non-archived classroom", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id, status: :active})

      assert {:error, :not_archived} = Classrooms.delete_classroom(classroom)
      # Classroom still exists
      assert Classrooms.get_classroom!(classroom.id).id == classroom.id
    end

    test "returns error when trying to delete closed classroom", %{teacher: teacher} do
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      {:ok, closed} = Classrooms.close_classroom(classroom)

      assert {:error, :not_archived} = Classrooms.delete_classroom(closed)
    end
  end

  describe "list_all_classrooms/0" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      {:ok, teacher: teacher}
    end

    test "lists all classrooms including archived", %{teacher: teacher} do
      active = classroom_fixture(%{teacher_id: teacher.id, name: "Active Classroom"})
      closed = classroom_fixture(%{teacher_id: teacher.id, name: "Closed Classroom"})
      {:ok, _} = Classrooms.close_classroom(closed)
      archived = classroom_fixture(%{teacher_id: teacher.id, name: "Archived Classroom"})
      {:ok, _} = Classrooms.archive_classroom(archived)

      classrooms = Classrooms.list_all_classrooms()
      ids = Enum.map(classrooms, & &1.id)

      assert active.id in ids
      assert closed.id in ids
      assert archived.id in ids
    end

    test "filters by status", %{teacher: teacher} do
      active = classroom_fixture(%{teacher_id: teacher.id, name: "Active Classroom"})
      archived = classroom_fixture(%{teacher_id: teacher.id, name: "Archived Classroom"})
      {:ok, _} = Classrooms.archive_classroom(archived)

      active_classrooms = Classrooms.list_all_classrooms(status: :active)
      assert length(active_classrooms) >= 1
      assert active.id in Enum.map(active_classrooms, & &1.id)
      refute archived.id in Enum.map(active_classrooms, & &1.id)

      archived_classrooms = Classrooms.list_all_classrooms(status: :archived)
      assert archived.id in Enum.map(archived_classrooms, & &1.id)
      refute active.id in Enum.map(archived_classrooms, & &1.id)
    end

    test "filters by teacher_id", %{teacher: teacher} do
      other_teacher = user_fixture(%{type: "teacher"})
      teacher_classroom = classroom_fixture(%{teacher_id: teacher.id, name: "Teacher Classroom"})

      other_classroom =
        classroom_fixture(%{teacher_id: other_teacher.id, name: "Other Classroom"})

      teacher_classrooms = Classrooms.list_all_classrooms(teacher_id: teacher.id)
      ids = Enum.map(teacher_classrooms, & &1.id)

      assert teacher_classroom.id in ids
      refute other_classroom.id in ids
    end
  end

  # Helper function
  defp classroom_fixture(attrs) do
    teacher_id = attrs[:teacher_id] || user_fixture(%{type: "teacher"}).id

    {:ok, classroom} =
      %{name: "Test Classroom", teacher_id: teacher_id}
      |> Map.merge(attrs)
      |> Classrooms.create_classroom()

    classroom
  end
end
