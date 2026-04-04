defmodule Medoru.Accounts.UserTypeTest do
  use Medoru.DataCase

  alias Medoru.Accounts
  alias Medoru.Accounts.User

  describe "user types" do
    test "default type is student" do
      {:ok, user} =
        Accounts.register_user_with_oauth(%{
          email: "test@example.com",
          provider: "google",
          provider_uid: "123",
          name: "Test User"
        })

      assert user.type == "student"
      assert User.student?(user)
      refute User.teacher?(user)
      refute User.admin?(user)
    end

    test "admin? returns true for admin users" do
      {:ok, user} =
        Accounts.register_user_with_oauth(%{
          email: "admin@example.com",
          provider: "google",
          provider_uid: "456",
          name: "Admin User"
        })

      {:ok, user} = Accounts.update_user_type(user, "admin")

      assert User.admin?(user)
      assert User.teacher?(user)
      refute User.student?(user)
    end

    test "teacher? returns true for teachers and admins" do
      {:ok, teacher} =
        Accounts.register_user_with_oauth(%{
          email: "teacher@example.com",
          provider: "google",
          provider_uid: "789",
          name: "Teacher User"
        })

      {:ok, teacher} = Accounts.update_user_type(teacher, "teacher")

      assert User.teacher?(teacher)
      refute User.admin?(teacher)

      {:ok, admin} =
        Accounts.register_user_with_oauth(%{
          email: "admin2@example.com",
          provider: "google",
          provider_uid: "abc",
          name: "Admin User"
        })

      {:ok, admin} = Accounts.update_user_type(admin, "admin")

      assert User.teacher?(admin)
    end

    test "update_user_type/2 changes user type" do
      {:ok, user} =
        Accounts.register_user_with_oauth(%{
          email: "change@example.com",
          provider: "google",
          provider_uid: "def",
          name: "Change User"
        })

      assert user.type == "student"

      {:ok, updated} = Accounts.update_user_type(user, "teacher")
      assert updated.type == "teacher"
    end

    test "types/0 returns all valid types" do
      assert User.types() == ["student", "teacher", "admin"]
    end

    test "moderator? returns true based on moderator flag" do
      {:ok, user} =
        Accounts.register_user_with_oauth(%{
          email: "mod@example.com",
          provider: "google",
          provider_uid: "mod123",
          name: "Mod User"
        })

      refute User.moderator?(user)

      {:ok, user} = Accounts.update_user_moderator(user, true)
      assert User.moderator?(user)
      assert User.staff?(user)
      refute User.admin?(user)
    end

    test "staff? returns true for admins and moderators" do
      {:ok, admin} =
        Accounts.register_user_with_oauth(%{
          email: "staff_admin@example.com",
          provider: "google",
          provider_uid: "sa123",
          name: "Staff Admin"
        })

      {:ok, admin} = Accounts.update_user_type(admin, "admin")
      assert User.staff?(admin)
      refute User.moderator?(admin)

      {:ok, mod} =
        Accounts.register_user_with_oauth(%{
          email: "staff_mod@example.com",
          provider: "google",
          provider_uid: "sm123",
          name: "Staff Mod"
        })

      {:ok, mod} = Accounts.update_user_moderator(mod, true)
      assert User.staff?(mod)
      refute User.admin?(mod)

      {:ok, teacher} =
        Accounts.register_user_with_oauth(%{
          email: "staff_teacher@example.com",
          provider: "google",
          provider_uid: "st123",
          name: "Staff Teacher"
        })

      {:ok, teacher} = Accounts.update_user_type(teacher, "teacher")
      refute User.staff?(teacher)
    end
  end

  describe "list_users_for_admin/1" do
    setup do
      # Create users of different types
      {:ok, student} =
        Accounts.register_user_with_oauth(%{
          email: "student_test@example.com",
          provider: "google",
          provider_uid: "s1",
          name: "Student Test"
        })

      {:ok, teacher} =
        Accounts.register_user_with_oauth(%{
          email: "teacher_test@example.com",
          provider: "google",
          provider_uid: "t1",
          name: "Teacher Test"
        })

      {:ok, teacher} = Accounts.update_user_type(teacher, "teacher")

      {:ok, admin} =
        Accounts.register_user_with_oauth(%{
          email: "admin_test@example.com",
          provider: "google",
          provider_uid: "a1",
          name: "Admin Test"
        })

      {:ok, admin} = Accounts.update_user_type(admin, "admin")

      %{student: student, teacher: teacher, admin: admin}
    end

    test "returns all users by default", %{student: s, teacher: t, admin: a} do
      {users, count} = Accounts.list_users_for_admin()
      emails = Enum.map(users, & &1.email)

      assert count >= 3
      assert s.email in emails
      assert t.email in emails
      assert a.email in emails
    end

    test "filters by type", %{student: s, teacher: t, admin: a} do
      {students, _student_count} = Accounts.list_users_for_admin(type: "student")
      student_emails = Enum.map(students, & &1.email)

      assert s.email in student_emails
      refute t.email in student_emails
      refute a.email in student_emails

      {teachers, _} = Accounts.list_users_for_admin(type: "teacher")
      teacher_emails = Enum.map(teachers, & &1.email)

      assert t.email in teacher_emails

      {admins, _} = Accounts.list_users_for_admin(type: "admin")
      admin_emails = Enum.map(admins, & &1.email)

      assert a.email in admin_emails
    end

    test "searches by email", %{student: s} do
      {users, _} = Accounts.list_users_for_admin(search: "student_test")
      emails = Enum.map(users, & &1.email)

      assert s.email in emails
    end

    test "searches by name", %{teacher: t} do
      {users, _} = Accounts.list_users_for_admin(search: "Teacher Test")
      emails = Enum.map(users, & &1.email)

      assert t.email in emails
    end

    test "supports pagination" do
      {users, _} = Accounts.list_users_for_admin(page: 1, per_page: 2)
      assert length(users) <= 2
    end
  end

  describe "get_user_for_admin!/1" do
    test "returns user with profile and stats" do
      {:ok, user} =
        Accounts.register_user_with_oauth(%{
          email: "preload@example.com",
          provider: "google",
          provider_uid: "pre",
          name: "Preload User"
        })

      result = Accounts.get_user_for_admin!(user.id)

      assert result.id == user.id
      assert result.profile != nil
      assert result.stats != nil
    end
  end
end
