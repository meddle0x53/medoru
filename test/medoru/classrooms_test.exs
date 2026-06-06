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

  describe "classroom chat sync" do
    setup do
      {:ok, teacher: user_fixture(%{type: "teacher"}), student: user_fixture(%{type: "student"})}
    end

    test "create_classroom/1 auto-creates a classroom chat conversation", %{teacher: teacher} do
      assert {:ok, %Classroom{} = classroom} =
               Classrooms.create_classroom(%{name: "Chat Test", teacher_id: teacher.id})

      conversation = Medoru.Chat.get_classroom_conversation(classroom.id)
      assert conversation != nil
      assert conversation.title == "Chat Test"
      assert conversation.is_group == true
      assert Enum.any?(conversation.participants, &(&1.user_id == teacher.id))
    end

    test "approve_membership/1 adds student to classroom chat", %{
      teacher: teacher,
      student: student
    } do
      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: true})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)

      # Before approval, student is not in chat
      conv = Medoru.Chat.get_classroom_conversation(classroom.id)
      refute Enum.any?(conv.participants, &(&1.user_id == student.id))

      # After approval, student is in chat
      {:ok, _} = Classrooms.approve_membership(membership)
      conv = Medoru.Chat.get_classroom_conversation(classroom.id)
      assert Enum.any?(conv.participants, &(&1.user_id == student.id))
    end

    test "remove_member/1 marks student as left in classroom chat", %{
      teacher: teacher,
      student: student
    } do
      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)

      # Student is in chat after auto-approve join
      conv = Medoru.Chat.get_classroom_conversation(classroom.id)
      participant = Enum.find(conv.participants, &(&1.user_id == student.id))
      assert participant.has_left == false

      # After removal, marked as left (query directly since get_classroom_conversation filters left users)
      {:ok, _} = Classrooms.remove_member(membership)

      participant =
        Medoru.Chat.ConversationParticipant
        |> Medoru.Repo.get_by(conversation_id: conv.id, user_id: student.id)

      assert participant.has_left == true
    end

    test "leave_classroom/1 marks student as left in classroom chat", %{
      teacher: teacher,
      student: student
    } do
      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      conv = Medoru.Chat.get_classroom_conversation(classroom.id)

      # After leaving, marked as left (query directly since get_classroom_conversation filters left users)
      {:ok, _} = Classrooms.leave_classroom(membership)

      participant =
        Medoru.Chat.ConversationParticipant
        |> Medoru.Repo.get_by(conversation_id: conv.id, user_id: student.id)

      assert participant.has_left == true
    end

    test "re-joining re-adds student to classroom chat", %{teacher: teacher, student: student} do
      classroom = classroom_fixture(%{teacher_id: teacher.id, should_approve_memberships: false})

      # First join
      {:ok, membership1} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.leave_classroom(membership1)

      # Re-join
      {:ok, _membership2} = Classrooms.apply_to_join(classroom.id, student.id)

      conv = Medoru.Chat.get_classroom_conversation(classroom.id)
      participant = Enum.find(conv.participants, &(&1.user_id == student.id))
      assert participant.has_left == false
    end
  end

  describe "list_visible_classrooms/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      other_teacher = user_fixture(%{type: "teacher"})

      # Teacher's own classroom
      {:ok, own_classroom} =
        Classrooms.create_classroom(%{
          name: "Own Classroom",
          teacher_id: teacher.id,
          public: false
        })

      # Public classroom by another teacher
      {:ok, public_classroom} =
        Classrooms.create_classroom(%{
          name: "Public Classroom",
          teacher_id: other_teacher.id,
          public: true
        })

      # Student joined classroom
      {:ok, joined_classroom} =
        Classrooms.create_classroom(%{
          name: "Joined Classroom",
          teacher_id: other_teacher.id,
          public: false,
          should_approve_memberships: false
        })

      {:ok, _} = Classrooms.apply_to_join(joined_classroom.id, student.id)

      # Archived classroom (should not appear)
      {:ok, archived_classroom} =
        Classrooms.create_classroom(%{
          name: "Archived Classroom",
          teacher_id: other_teacher.id,
          public: true
        })

      {:ok, _} = Classrooms.archive_classroom(archived_classroom)

      %{
        teacher: teacher,
        student: student,
        own_classroom: own_classroom,
        public_classroom: public_classroom,
        joined_classroom: joined_classroom,
        archived_classroom: archived_classroom
      }
    end

    test "returns owned classrooms for teacher", %{
      teacher: teacher,
      own_classroom: own,
      public_classroom: public
    } do
      result = Classrooms.list_visible_classrooms(teacher.id)
      ids = Enum.map(result.classrooms, & &1.id)

      assert own.id in ids
      assert public.id in ids
    end

    test "returns joined and public classrooms for student", %{
      student: student,
      joined_classroom: joined,
      public_classroom: public,
      own_classroom: own
    } do
      result = Classrooms.list_visible_classrooms(student.id)
      ids = Enum.map(result.classrooms, & &1.id)

      assert joined.id in ids
      assert public.id in ids
      refute own.id in ids
    end

    test "excludes archived classrooms", %{student: student, archived_classroom: archived} do
      result = Classrooms.list_visible_classrooms(student.id)
      ids = Enum.map(result.classrooms, & &1.id)

      refute archived.id in ids
    end

    test "supports search by name", %{teacher: teacher} do
      result = Classrooms.list_visible_classrooms(teacher.id, search: "Own")
      assert length(result.classrooms) == 1
      assert hd(result.classrooms).name == "Own Classroom"
    end

    test "supports pagination", %{teacher: teacher} do
      result = Classrooms.list_visible_classrooms(teacher.id, page: 1, per_page: 1)
      assert length(result.classrooms) == 1
      assert result.total_pages >= 2
    end
  end

  describe "list_public_classrooms/0" do
    test "returns only active public classrooms" do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, public} =
        Classrooms.create_classroom(%{
          name: "Public Active",
          teacher_id: teacher.id,
          public: true
        })

      {:ok, private} =
        Classrooms.create_classroom(%{
          name: "Private Active",
          teacher_id: teacher.id,
          public: false
        })

      {:ok, closed_public} =
        Classrooms.create_classroom(%{
          name: "Public Closed",
          teacher_id: teacher.id,
          public: true
        })

      {:ok, _} = Classrooms.close_classroom(closed_public)

      public_ids = Enum.map(Classrooms.list_public_classrooms(), & &1.id)

      assert public.id in public_ids
      refute private.id in public_ids
      refute closed_public.id in public_ids
    end
  end

  describe "user_classroom_status/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      %{teacher: teacher, student: student, classroom: classroom}
    end

    test "returns :owner for classroom owner", %{teacher: teacher, classroom: classroom} do
      assert Classrooms.user_classroom_status(classroom.id, teacher.id) == :owner
    end

    test "returns :none for non-member", %{student: student, classroom: classroom} do
      assert Classrooms.user_classroom_status(classroom.id, student.id) == :none
    end

    test "returns :pending for pending application", %{
      student: student,
      classroom: classroom
    } do
      {:ok, _} = Classrooms.apply_to_join(classroom.id, student.id)
      assert Classrooms.user_classroom_status(classroom.id, student.id) == :pending
    end

    test "returns :member for approved member", %{
      student: student,
      classroom: classroom
    } do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      assert Classrooms.user_classroom_status(classroom.id, student.id) == :member
    end
  end

  describe "get_membership!/1 and list_classroom_memberships/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      %{teacher: teacher, student: student, classroom: classroom}
    end

    test "get_membership!/1 returns the membership", %{student: student, classroom: classroom} do
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      found = Classrooms.get_membership!(membership.id)
      assert found.id == membership.id
    end

    test "get_membership!/1 raises for non-existent id", %{} do
      assert_raise Ecto.NoResultsError, fn ->
        Classrooms.get_membership!(Ecto.UUID.generate())
      end
    end

    test "list_classroom_memberships/1 returns all memberships", %{
      student: student,
      classroom: classroom
    } do
      assert Classrooms.list_classroom_memberships(classroom.id) == []

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      assert length(Classrooms.list_classroom_memberships(classroom.id)) == 1
      assert hd(Classrooms.list_classroom_memberships(classroom.id)).id == membership.id
    end
  end

  describe "get_classroom_stats_batch/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student1 = user_fixture(%{type: "student"})
      student2 = user_fixture(%{type: "student"})

      classroom1 = classroom_fixture(%{teacher_id: teacher.id})
      classroom2 = classroom_fixture(%{teacher_id: teacher.id})

      {:ok, m1} = Classrooms.apply_to_join(classroom1.id, student1.id)
      {:ok, _} = Classrooms.approve_membership(m1)
      {:ok, _} = Classrooms.add_member_points(m1, 100)

      {:ok, m2} = Classrooms.apply_to_join(classroom1.id, student2.id)
      {:ok, _} = Classrooms.approve_membership(m2)

      {:ok, m3} = Classrooms.apply_to_join(classroom2.id, student1.id)
      {:ok, _} = Classrooms.approve_membership(m3)
      {:ok, _} = Classrooms.add_member_points(m3, 50)

      %{
        classroom1: classroom1,
        classroom2: classroom2
      }
    end

    test "returns stats for multiple classrooms", %{
      classroom1: c1,
      classroom2: c2
    } do
      stats = Classrooms.get_classroom_stats_batch([c1.id, c2.id])

      assert stats[c1.id].total_members == 2
      assert stats[c1.id].total_points == 100
      assert stats[c2.id].total_members == 1
      assert stats[c2.id].total_points == 50
    end

    test "returns empty map for empty list" do
      assert Classrooms.get_classroom_stats_batch([]) == %{}
    end
  end

  describe "get_classroom_leaderboard/2" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student1 = user_fixture(%{type: "student", email: "s1@example.com"})
      student2 = user_fixture(%{type: "student", email: "s2@example.com"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})

      {:ok, m1} = Classrooms.apply_to_join(classroom.id, student1.id)
      {:ok, _} = Classrooms.approve_membership(m1)
      {:ok, _} = Classrooms.add_member_points(m1, 200)

      {:ok, m2} = Classrooms.apply_to_join(classroom.id, student2.id)
      {:ok, _} = Classrooms.approve_membership(m2)
      {:ok, _} = Classrooms.add_member_points(m2, 100)

      %{classroom: classroom, student1: student1, student2: student2}
    end

    test "returns members sorted by points descending", %{classroom: classroom} do
      leaderboard = Classrooms.get_classroom_leaderboard(classroom.id)
      assert length(leaderboard) == 2
      assert hd(leaderboard).points == 200
      assert hd(tl(leaderboard)).points == 100
    end

    test "limits results with limit option", %{classroom: classroom} do
      leaderboard = Classrooms.get_classroom_leaderboard(classroom.id, limit: 1)
      assert length(leaderboard) == 1
      assert hd(leaderboard).points == 200
    end
  end

  describe "get_test_leaderboard/3" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student1 = user_fixture(%{type: "student", email: "s1@example.com"})
      student2 = user_fixture(%{type: "student", email: "s2@example.com"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})

      {:ok, m1} = Classrooms.apply_to_join(classroom.id, student1.id)
      {:ok, _} = Classrooms.approve_membership(m1)
      {:ok, _} = Classrooms.add_member_points(m1, 150)

      {:ok, m2} = Classrooms.apply_to_join(classroom.id, student2.id)
      {:ok, _} = Classrooms.approve_membership(m2)
      {:ok, _} = Classrooms.add_member_points(m2, 75)

      %{classroom: classroom, student1: student1, student2: student2}
    end

    test "returns empty leaderboard when no test attempts", %{classroom: classroom} do
      test_id = Ecto.UUID.generate()
      leaderboard = Classrooms.get_test_leaderboard(classroom.id, test_id)
      assert leaderboard == []
    end
  end

  describe "get_or_create_lesson_progress/3" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      lesson = Medoru.ContentFixtures.lesson_fixture()
      %{teacher: teacher, student: student, classroom: classroom, lesson: lesson}
    end

    test "creates new progress when none exists", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      {:ok, progress} =
        Classrooms.get_or_create_lesson_progress(classroom.id, student.id, lesson.id)

      assert progress.classroom_id == classroom.id
      assert progress.user_id == student.id
      assert progress.lesson_id == lesson.id
      assert progress.status == "not_started"
    end

    test "returns existing progress when it exists", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      {:ok, progress1} =
        Classrooms.get_or_create_lesson_progress(classroom.id, student.id, lesson.id)

      {:ok, progress2} =
        Classrooms.get_or_create_lesson_progress(classroom.id, student.id, lesson.id)

      assert progress1.id == progress2.id
    end
  end

  describe "start_lesson/3 and complete_lesson/5" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      lesson = Medoru.ContentFixtures.lesson_fixture()

      # Add student as approved member
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      %{teacher: teacher, student: student, classroom: classroom, lesson: lesson}
    end

    test "start_lesson marks progress as in_progress", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      {:ok, progress} =
        Classrooms.start_lesson(classroom.id, student.id, lesson.id)

      assert progress.status == "in_progress"
      assert progress.started_at != nil
    end

    test "complete_lesson marks progress as completed with points", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      # Create a real test and test session to satisfy FK constraints
      test = Medoru.TestsFixtures.test_fixture(%{status: :published})
      {:ok, test_session} = Medoru.Tests.start_test_session(student.id, test.id)
      {:ok, test_session} = Medoru.Tests.complete_test_session(test_session.id)

      {:ok, _} = Classrooms.start_lesson(classroom.id, student.id, lesson.id)

      {:ok, progress} =
        Classrooms.complete_lesson(
          classroom.id,
          student.id,
          lesson.id,
          test_session.id,
          50
        )

      assert progress.status == "completed"
      assert progress.completed_at != nil
      assert progress.points_earned == 50
    end
  end

  describe "list_user_lesson_progress/2 and list_classroom_lesson_progress/1" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      lesson = Medoru.ContentFixtures.lesson_fixture()
      %{teacher: teacher, student: student, classroom: classroom, lesson: lesson}
    end

    test "list_user_lesson_progress returns all user progress", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      {:ok, _} =
        Classrooms.start_lesson(classroom.id, student.id, lesson.id)

      progress = Classrooms.list_user_lesson_progress(classroom.id, student.id)
      assert length(progress) == 1
      assert hd(progress).lesson_id == lesson.id
    end

    test "list_classroom_lesson_progress returns all classroom progress", %{
      student: student,
      classroom: classroom,
      lesson: lesson
    } do
      {:ok, _} =
        Classrooms.start_lesson(classroom.id, student.id, lesson.id)

      progress = Classrooms.list_classroom_lesson_progress(classroom.id)
      assert length(progress) == 1
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
