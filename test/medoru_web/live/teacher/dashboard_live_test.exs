defmodule MedoruWeb.Teacher.DashboardLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  describe "Teacher dashboard" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      student = user_fixture(%{type: "student"})
      admin = user_fixture(%{type: "admin"})
      %{teacher: teacher, student: student, admin: admin}
    end

    test "teacher can access dashboard", %{conn: conn, teacher: teacher} do
      {:ok, _view, html} = conn |> log_in_user(teacher) |> live(~p"/teacher")

      assert html =~ "Teacher"
      assert html =~ "My Classrooms"
      assert html =~ "My Tests"
      assert html =~ "Custom Lessons"
      assert html =~ "Grammar Lessons"
    end

    test "student is redirected from teacher dashboard", %{
      conn: conn,
      student: student
    } do
      {:error, {:redirect, %{to: "/dashboard", flash: flash}}} =
        conn |> log_in_user(student) |> live(~p"/teacher")

      assert flash["error"] == "You must be a teacher to access this page."
    end

    test "admin can access teacher dashboard", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/teacher")

      assert html =~ "Teacher"
    end
  end
end
