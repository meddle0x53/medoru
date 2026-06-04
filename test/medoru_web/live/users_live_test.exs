defmodule MedoruWeb.UsersLiveTest do
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

  describe "UsersLive.Index" do
    test "renders user directory", %{conn: conn} do
      user_with_display_name(%{display_name: "TestUser"})

      {:ok, _view, html} = live(conn, ~p"/users")

      assert html =~ "Users"
      assert html =~ "Discover other Japanese learners"
      assert html =~ "TestUser"
    end

    test "shows search results", %{conn: conn} do
      user_with_display_name(%{display_name: "AliceWonder"})
      user_with_display_name(%{display_name: "BobBuilder"})

      {:ok, view, _html} = live(conn, ~p"/users")

      html =
        view
        |> form("form", %{search: "Alice"})
        |> render_submit()

      assert html =~ "AliceWonder"
      refute html =~ "BobBuilder"
    end

    test "hides users without display names", %{conn: conn} do
      user_fixture_with_registration()

      {:ok, _view, html} = live(conn, ~p"/users")

      # Only users with display names are shown
      refute html =~ "NoDisplayName"
    end

    test "shows message button for logged-in user", %{conn: conn} do
      viewer = user_with_display_name()
      user_with_display_name(%{display_name: "TargetUser"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/users")

      assert html =~ "Message"
    end

    test "blocker can still find blocked user via search", %{conn: conn} do
      blocker = user_with_display_name(%{display_name: "BlockerX"})
      blocked = user_with_display_name(%{display_name: "BlockedUserX"})

      Medoru.Social.block_user(blocker.id, blocked.id)

      {:ok, view, _html} = conn |> log_in_user(blocker) |> live(~p"/users")

      html =
        view
        |> form("form", %{search: "BlockedUserX"})
        |> render_submit()

      assert html =~ "BlockedUserX"
    end

    test "blocked user cannot find blocker via search", %{conn: conn} do
      blocker = user_with_display_name(%{display_name: "BlockerX"})
      blocked = user_with_display_name(%{display_name: "BlockedUserX"})

      Medoru.Social.block_user(blocker.id, blocked.id)

      {:ok, view, _html} = conn |> log_in_user(blocked) |> live(~p"/users")

      html =
        view
        |> form("form", %{search: "BlockerX"})
        |> render_submit()

      assert html =~ "No users found"
    end

    test "hides users with private profiles from directory", %{conn: conn} do
      _public_user = user_with_display_name(%{display_name: "PublicUser"})
      private_user = user_with_display_name(%{display_name: "PrivateUser"})

      Medoru.Accounts.update_profile(private_user.profile, %{is_public: false})

      {:ok, _view, html} = live(conn, ~p"/users")

      assert html =~ "PublicUser"
      refute html =~ "PrivateUser"
    end

    test "supports user selection for group chat", %{conn: conn} do
      viewer = user_with_display_name()
      target = user_with_display_name(%{display_name: "TargetUser"})

      # Viewer must follow target to see them in the directory
      Medoru.Social.follow_user(viewer.id, target.id)

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/users")

      # Select user
      html =
        view
        |> element("input[phx-click='toggle_select']")
        |> render_click(%{"user_id" => target.id})

      assert html =~ "1 selected"
      assert html =~ "Group Chat"

      # Clear selection
      html =
        view
        |> element("button[phx-click='clear_selection']")
        |> render_click()

      refute html =~ "1 selected"
    end

    test "navigates to group creation", %{conn: conn} do
      viewer = user_with_display_name()
      target = user_with_display_name(%{display_name: "TargetUser"})

      # Viewer must follow target to see them in the directory
      Medoru.Social.follow_user(viewer.id, target.id)

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/users")

      # Select user
      view
      |> element("input[phx-click='toggle_select']")
      |> render_click(%{"user_id" => target.id})

      # Create group
      result =
        view
        |> element("button[phx-click='create_group']")
        |> render_click()

      assert {:error, {:live_redirect, %{to: "/messages/new-group?" <> _}}} = result
    end

    test "supports pagination", %{conn: conn} do
      # Create many users with display names to trigger pagination
      for i <- 1..30 do
        user_with_display_name(%{display_name: "User#{i}"})
      end

      {:ok, view, _html} = live(conn, ~p"/users")

      assert has_element?(view, "button[phx-click='change_page']")
    end
  end

  describe "UserLive.Show" do
    test "renders public profile", %{conn: conn} do
      user = user_with_display_name(%{display_name: "PublicUser"})

      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}")

      assert html =~ "PublicUser"
      assert html =~ "Member since"
    end

    test "shows online badge when user is online", %{conn: conn} do
      viewer = user_with_display_name()

      # viewer goes to messages page to track online presence
      {:ok, _view, _html} = conn |> log_in_user(viewer) |> live(~p"/messages")

      # viewer's own profile shows online badge
      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/users/#{viewer.id}")

      assert html =~ "Online"
    end

    test "shows message and block buttons for other users", %{conn: conn} do
      viewer = user_with_display_name()
      target = user_with_display_name(%{display_name: "TargetUser"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/users/#{target.id}")

      assert html =~ "Message"
      assert html =~ "Block"
    end

    test "blocks a user", %{conn: conn} do
      viewer = user_with_display_name()
      target = user_with_display_name(%{display_name: "TargetUser"})

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/users/#{target.id}")

      html =
        view
        |> element("button[phx-click='block_user']")
        |> render_click()

      assert html =~ "User blocked"
      assert html =~ "Unblock"
    end

    test "unblocks a user", %{conn: conn} do
      viewer = user_with_display_name()
      target = user_with_display_name(%{display_name: "TargetUser"})

      Medoru.Social.block_user(viewer.id, target.id)

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/users/#{target.id}")

      html =
        view
        |> element("button[phx-click='unblock_user']")
        |> render_click()

      assert html =~ "User unblocked"
      assert html =~ "Message"
    end

    test "redirects for invalid user id", %{conn: conn} do
      {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/users/invalid-id")
    end

    test "shows admin actions for admin user", %{conn: conn} do
      admin = user_fixture_with_registration(%{type: "admin"})
      target = user_with_display_name(%{display_name: "TargetUser"})

      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/users/#{target.id}")

      assert html =~ "Admin Actions"
      assert html =~ "Reset Daily Challenges"
    end
  end
end
