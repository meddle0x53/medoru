defmodule MedoruWeb.UserLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts

  defp user_with_display_name(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "User#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "UserLive.Show" do
    test "renders public profile", %{conn: conn} do
      user = user_with_display_name(%{display_name: "PublicUser"})

      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}")

      assert html =~ "PublicUser"
      assert html =~ "Profile"
    end

    test "redirects when viewer is blocked by profile owner", %{conn: conn} do
      blocker = user_with_display_name(%{display_name: "Blocker"})
      viewer = user_with_display_name()

      Medoru.Social.block_user(blocker.id, viewer.id)

      {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found."}}}} =
        conn |> log_in_user(viewer) |> live(~p"/users/#{blocker.id}")
    end

    test "renders profile when viewer has blocked the owner", %{conn: conn} do
      viewer = user_with_display_name()
      blocked = user_with_display_name(%{display_name: "BlockedUser"})

      Medoru.Social.block_user(viewer.id, blocked.id)

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/users/#{blocked.id}")

      # Viewer can still see blocked user's profile to manage the block
      assert html =~ "BlockedUser"
      assert html =~ "Unblock"
    end
  end
end
