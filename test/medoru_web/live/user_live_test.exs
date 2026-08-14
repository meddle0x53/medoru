defmodule MedoruWeb.UserLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.{Accounts, Social}

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

    test "renders learning language on profile", %{conn: conn} do
      user = user_with_display_name(%{display_name: "LanguageLearner"})
      {:ok, user} = Accounts.update_user(user, %{learning_language: "bulgarian"})

      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}")

      assert html =~ "Learning Bulgarian"
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

    test "renders follower/following counts as links on own profile", %{conn: conn} do
      user = user_with_display_name(%{display_name: "Owner"})

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/users/#{user.id}")

      assert html =~ "href=\"/users/#{user.id}/followers\""
      assert html =~ "href=\"/users/#{user.id}/following\""
    end

    test "renders follower/following counts as plain text on another user's profile", %{
      conn: conn
    } do
      owner = user_with_display_name(%{display_name: "Owner"})
      viewer = user_with_display_name()

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}")

      refute html =~ "href=\"/users/#{owner.id}/followers\""
      refute html =~ "href=\"/users/#{owner.id}/following\""
      assert html =~ "followers"
      assert html =~ "following"
    end

    test "renders follower/following counts as plain text for anonymous viewers", %{conn: conn} do
      user = user_with_display_name(%{display_name: "PublicUser"})

      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}")

      refute html =~ "href=\"/users/#{user.id}/followers\""
      refute html =~ "href=\"/users/#{user.id}/following\""
    end

    test "records a visit when an authenticated user views another profile", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      viewer = user_with_display_name(%{display_name: "Viewer"})

      {:ok, _view, _html} = conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}")

      assert Social.count_visitors(owner.id) == 1
    end

    test "does not record a visit for self views", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})

      {:ok, _view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}")

      assert Social.count_visitors(owner.id) == 0
    end

    test "does not record a visit when blocked", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      viewer = user_with_display_name(%{display_name: "Viewer"})

      Social.block_user(owner.id, viewer.id)

      {:error, {:live_redirect, _}} =
        conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}")

      assert Social.count_visitors(owner.id) == 0
    end

    test "shows visitors link for teacher owner", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Teacher", type: "teacher"})

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}")

      assert html =~ "href=\"/users/#{owner.id}/visitors\""
    end

    test "shows visitors link for moderator owner", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Moderator"})
      {:ok, owner} = Accounts.update_user(owner, %{moderator: true})

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}")

      assert html =~ "href=\"/users/#{owner.id}/visitors\""
    end

    test "hides visitors link for student owner", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Student", type: "student"})

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}")

      refute html =~ "href=\"/users/#{owner.id}/visitors\""
    end
  end

  describe "UserLive.Followers" do
    test "renders followers for the profile owner", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      follower = user_with_display_name(%{display_name: "FollowerOne"})

      {:ok, _} = Social.follow_user(follower.id, owner.id)

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/followers")

      assert html =~ "Followers"
      assert html =~ "FollowerOne"
    end

    test "owner can follow back a follower", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      follower = user_with_display_name(%{display_name: "FollowerOne"})

      {:ok, _} = Social.follow_user(follower.id, owner.id)

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/followers")

      assert view
             |> element("button", "Follow")
             |> render_click(%{"user_id" => follower.id}) =~ "Unfollow"

      assert Social.following?(owner.id, follower.id)
    end

    test "owner can unfollow a follower", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      follower = user_with_display_name(%{display_name: "FollowerOne"})

      {:ok, _} = Social.follow_user(follower.id, owner.id)
      {:ok, _} = Social.follow_user(owner.id, follower.id)

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/followers")

      assert view
             |> element("button", "Unfollow")
             |> render_click(%{"user_id" => follower.id}) =~ "Follow"

      refute Social.following?(owner.id, follower.id)
    end

    test "redirects non-owner to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      viewer = user_with_display_name()
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}/followers")
    end

    test "redirects anonymous viewer to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        live(conn, ~p"/users/#{owner.id}/followers")
    end
  end

  describe "UserLive.Following" do
    test "renders following list for the profile owner", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      followed = user_with_display_name(%{display_name: "FollowedOne"})

      {:ok, _} = Social.follow_user(owner.id, followed.id)

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/following")

      assert html =~ "Following"
      assert html =~ "FollowedOne"
    end

    test "owner can unfollow a user from the following list", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      followed = user_with_display_name(%{display_name: "FollowedOne"})

      {:ok, _} = Social.follow_user(owner.id, followed.id)

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/following")

      assert view
             |> element("button", "Unfollow")
             |> render_click(%{"user_id" => followed.id}) =~ "Follow"

      refute Social.following?(owner.id, followed.id)
    end

    test "redirects non-owner to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      viewer = user_with_display_name()
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}/following")
    end
  end

  describe "UserLive.Visitors" do
    test "renders visitors for the profile owner (teacher)", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner", type: "teacher"})
      visitor = user_with_display_name(%{display_name: "VisitorOne"})

      Social.record_profile_visit(visitor.id, owner.id)

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/visitors")

      assert html =~ "Visitors"
      assert html =~ "VisitorOne"
    end

    test "renders visitors for the profile owner (moderator)", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner"})
      {:ok, owner} = Accounts.update_user(owner, %{moderator: true})
      visitor = user_with_display_name(%{display_name: "VisitorOne"})

      Social.record_profile_visit(visitor.id, owner.id)

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/visitors")

      assert html =~ "Visitors"
      assert html =~ "VisitorOne"
    end

    test "does not show blocked visitors", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner", type: "teacher"})
      visitor = user_with_display_name(%{display_name: "BlockedVisitor"})

      Social.record_profile_visit(visitor.id, owner.id)
      Social.block_user(owner.id, visitor.id)

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/visitors")

      assert html =~ "Visitors"
      refute html =~ "BlockedVisitor"
    end

    test "redirects non-owner to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner", type: "teacher"})
      viewer = user_with_display_name()
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        conn |> log_in_user(viewer) |> live(~p"/users/#{owner.id}/visitors")
    end

    test "redirects student owner to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner", type: "student"})
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/visitors")
    end

    test "redirects anonymous viewer to the profile page", %{conn: conn} do
      owner = user_with_display_name(%{display_name: "Owner", type: "teacher"})
      expected_path = "/users/#{owner.id}"

      {:error, {:live_redirect, %{to: ^expected_path, flash: %{"error" => _}}}} =
        live(conn, ~p"/users/#{owner.id}/visitors")
    end
  end
end
