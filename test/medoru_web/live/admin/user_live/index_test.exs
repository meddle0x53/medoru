defmodule MedoruWeb.Admin.UserLive.IndexTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  setup %{conn: conn} do
    admin = user_fixture(%{type: "admin", email: "admin@example.com"})
    conn = log_in_user(conn, admin)
    %{conn: conn, admin: admin}
  end

  describe "Index" do
    test "lists all users with last active information", %{conn: conn} do
      user = user_fixture(%{email: "student@example.com"})
      {:ok, user} = Medoru.Accounts.update_last_login(user)

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "User Management"
      assert html =~ user.email
      assert html =~ "Last Active"
      assert html =~ Calendar.strftime(user.last_login, "%b %d, %Y %H:%M")
    end

    test "shows 'Never' for users who have never logged in", %{conn: conn} do
      user_fixture(%{email: "never@example.com"})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "User Management"
      assert html =~ "Never"
    end

    test "shows the real learned kanji count instead of the cached stats counter",
         %{conn: conn} do
      user = user_fixture_with_stats(%{email: "student@example.com"})
      kanji = kanji_fixture()
      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})

      # Corrupt the cached counter to prove the list uses the source of truth
      {:ok, _} =
        Medoru.Accounts.update_stats(user.stats, %{total_kanji_learned: 999})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "User Management"
      assert html =~ user.email
      refute html =~ "999"
      assert html =~ "1"
    end

    test "non-admin users are redirected away", %{conn: conn} do
      student = user_fixture(%{type: "student", email: "student@example.com"})
      conn = log_in_user(conn, student)

      {:error, {:redirect, %{to: to}}} = live(conn, ~p"/admin/users")
      assert to == ~p"/dashboard"
    end
  end
end
