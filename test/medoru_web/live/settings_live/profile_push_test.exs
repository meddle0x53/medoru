defmodule MedoruWeb.SettingsLive.ProfilePushTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  describe "Profile Settings - Push Notifications" do
    test "shows push notification toggle", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/settings/profile")

      assert html =~ "Push Notifications"
      assert html =~ "Disabled"
      assert html =~ "Enable"
    end

    test "toggling push notifications updates the profile", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/settings/profile")

      # Click enable
      lv |> element("button[phx-click='toggle_push_notifications']") |> render_click()

      # The toggle should now show enabled state
      assert render(lv) =~ "Enabled"
      assert render(lv) =~ "Disable"

      # Verify DB was updated
      profile = Medoru.Accounts.get_profile_by_user!(user.id)
      assert profile.push_notifications_enabled == true
    end
  end
end
