defmodule MedoruWeb.SettingsLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  describe "Profile settings page" do
    setup do
      user = user_fixture_with_registration()
      %{user: user}
    end

    test "renders profile settings form", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "h1", "Profile Settings")
      assert has_element?(view, "input[name=\"user_profile[display_name]\"]")
      assert has_element?(view, "textarea[name=\"user_profile[bio]\"]")
    end

    test "updates profile with valid data", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      # Submit the form - render_submit returns redirect tuple on success
      result =
        view
        |> form("form",
          user_profile: %{display_name: "NewDisplayName", bio: "Hello, this is my bio!"}
        )
        |> render_submit()

      # Check that it redirects (success case)
      assert {:error, {:live_redirect, %{to: "/settings/profile"}}} = result

      # Verify the profile was updated
      profile = Medoru.Accounts.get_profile_by_user!(user.id)
      assert profile.display_name == "NewDisplayName"
      assert profile.bio == "Hello, this is my bio!"
    end

    test "validates display name uniqueness", %{conn: conn, user: user} do
      # Create another user with a display name
      other_user =
        user_fixture_with_registration(%{email: "other@example.com", provider_uid: "other123"})

      {:ok, _} = Medoru.Accounts.update_profile(other_user.profile, %{display_name: "TakenName"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      html =
        view
        |> form("form", user_profile: %{display_name: "TakenName"})
        |> render_submit()

      assert html =~ "is already taken"
    end

    test "validates display name format", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      html =
        view
        |> form("form", user_profile: %{display_name: "Invalid@Name#"})
        |> render_change()

      assert html =~ "can only contain letters"
    end
  end
end
