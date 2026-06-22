defmodule MedoruWeb.Admin.UserControllerTest do
  use MedoruWeb.ConnCase

  import Medoru.AccountsFixtures

  describe "impersonate/2" do
    test "admin can impersonate a non-admin user", %{conn: conn} do
      admin = user_fixture(%{type: "admin", email: "admin@example.com"})
      target = user_fixture(%{type: "student", email: "student@example.com"})

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/users/#{target.id}/impersonate")

      assert redirected_to(conn) == ~p"/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "You are now impersonating"

      assert get_session(conn, :user_id) == target.id
      assert get_session(conn, :impersonator_user_id) == admin.id

      target = Medoru.Accounts.get_user!(target.id)
      assert target.last_login
    end

    test "non-admin cannot impersonate", %{conn: conn} do
      student = user_fixture(%{type: "student"})
      target = user_fixture(%{type: "student", email: "target@example.com"})

      conn =
        conn
        |> log_in_user(student)
        |> post(~p"/admin/users/#{target.id}/impersonate")

      assert redirected_to(conn) == ~p"/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must be an admin"

      assert get_session(conn, :user_id) == student.id
      assert is_nil(get_session(conn, :impersonator_user_id))
    end

    test "admin cannot impersonate another admin", %{conn: conn} do
      admin = user_fixture(%{type: "admin", email: "admin@example.com"})
      other_admin = user_fixture(%{type: "admin", email: "other_admin@example.com"})

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/users/#{other_admin.id}/impersonate")

      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cannot impersonate another admin"

      assert get_session(conn, :user_id) == admin.id
      assert is_nil(get_session(conn, :impersonator_user_id))
    end

    test "returns error when target user does not exist", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/users/00000000-0000-0000-0000-000000000000/impersonate")

      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "User not found"
    end
  end

  describe "stop_impersonation/2" do
    test "restores original admin session", %{conn: conn} do
      admin = user_fixture(%{type: "admin", email: "admin@example.com"})
      target = user_fixture(%{type: "student", email: "student@example.com"})

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/users/#{target.id}/impersonate")

      assert get_session(conn, :user_id) == target.id
      assert get_session(conn, :impersonator_user_id) == admin.id

      conn = post(conn, ~p"/admin/users/stop-impersonation")

      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "logged back in as yourself"

      assert get_session(conn, :user_id) == admin.id
      assert is_nil(get_session(conn, :impersonator_user_id))
    end

    test "returns error when not impersonating", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/admin/users/stop-impersonation")

      assert redirected_to(conn) == ~p"/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not impersonating anyone"
    end
  end
end
