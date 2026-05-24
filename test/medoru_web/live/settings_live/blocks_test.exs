defmodule MedoruWeb.SettingsLive.BlocksTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts
  alias Medoru.Social

  defp user_with_display_name(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "User#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "SettingsLive.Blocks" do
    test "renders blocked users list", %{conn: conn} do
      user = user_with_display_name()
      blocked = user_with_display_name(%{display_name: "BlockedUser"})

      Social.block_user(user.id, blocked.id)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/settings/blocks")

      assert html =~ "Blocked Users"
      assert html =~ "BlockedUser"
      assert html =~ "Unblock"
    end

    test "shows empty state when no blocked users", %{conn: conn} do
      user = user_with_display_name()

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/settings/blocks")

      assert html =~ "No blocked users"
    end

    test "unblocks a user", %{conn: conn} do
      user = user_with_display_name()
      blocked = user_with_display_name(%{display_name: "BlockedUser"})

      Social.block_user(user.id, blocked.id)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/blocks")

      html =
        view
        |> element("button[phx-click='unblock']")
        |> render_click(%{"id" => blocked.id})

      assert html =~ "User unblocked"
      refute html =~ "BlockedUser"
    end

    test "redirects unauthenticated user", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/settings/blocks")
    end

    test "shows block date", %{conn: conn} do
      user = user_with_display_name()
      blocked = user_with_display_name(%{display_name: "BlockedUser"})

      Social.block_user(user.id, blocked.id)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/settings/blocks")

      assert html =~ "Blocked on"
    end

    test "shows block reason if present", %{conn: conn} do
      user = user_with_display_name()
      blocked = user_with_display_name(%{display_name: "BlockedUser"})

      Social.block_user(user.id, blocked.id, "Spam messages")

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/settings/blocks")

      assert html =~ "Spam messages"
    end
  end
end
