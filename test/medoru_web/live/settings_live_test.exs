defmodule MedoruWeb.SettingsLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts

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

    test "renders learning language form", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "h2", "Learning Language")
      assert has_element?(view, "select[name=\"user[learning_language]\"]")
      assert has_element?(view, "option[value=\"japanese\"]")
      assert has_element?(view, "option[value=\"english\"]")
      assert has_element?(view, "option[value=\"bulgarian\"]")
    end

    test "updates learning language", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      result =
        view
        |> form("#learning-language-form", user: %{learning_language: "english"})
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/settings/profile"}}} = result

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.learning_language == "english"
    end

    test "updates profile with valid data", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      # Submit the form - render_submit returns redirect tuple on success
      result =
        view
        |> form("#profile-form",
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

    test "updates safety mode setting", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      result =
        view
        |> form("#profile-form",
          user_profile: %{display_name: "SafetyTester", safety: "false"}
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/settings/profile"}}} = result

      profile = Medoru.Accounts.get_profile_by_user!(user.id)
      assert profile.display_name == "SafetyTester"
      assert profile.safety == false
    end

    test "changing a checkbox keeps the selected gender", %{conn: conn, user: user} do
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{gender: 0})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      html =
        view
        |> form("#profile-form",
          user_profile: %{gender: "0", notify_messaging: "true"}
        )
        |> render_change()

      select_html =
        Regex.run(~r/<select[^>]*name="user_profile\[gender\]"[\s\S]*?<\/select>/, html) |> hd()

      assert select_html =~ ~r/<option value="0" selected(="")?>/
    end

    test "validates display name uniqueness", %{conn: conn, user: user} do
      # Create another user with a display name
      other_user =
        user_fixture_with_registration(%{email: "other@example.com", provider_uid: "other123"})

      {:ok, _} = Medoru.Accounts.update_profile(other_user.profile, %{display_name: "TakenName"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      html =
        view
        |> form("#profile-form", user_profile: %{display_name: "TakenName"})
        |> render_submit()

      assert html =~ "is already taken"
    end

    test "creates API token", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "h2", "API Tokens")

      html =
        view
        |> form("#api-token-form", api_token: %{name: "Test Token", expires_in_days: "30"})
        |> render_submit()

      assert html =~ "API token created successfully"
      assert html =~ "Copy your token now"
      assert html =~ "<code"
    end

    test "deletes API token", %{conn: conn, user: user} do
      {:ok, token, _plaintext} =
        Medoru.Accounts.create_api_token(user.id, %{"name" => "To Delete"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "span", "To Delete")

      html =
        view
        |> element("button[phx-click=\"delete_api_token\"][phx-value-id=\"#{token.id}\"]")
        |> render_click()

      assert html =~ "API token revoked"
      refute html =~ "To Delete"
    end

    test "enforces API token limit", %{conn: conn, user: user} do
      for i <- 1..3 do
        {:ok, _, _} = Medoru.Accounts.create_api_token(user.id, %{"name" => "Token #{i}"})
      end

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      refute has_element?(view, "#api-token-form")
      assert has_element?(view, "p", "Token limit reached")
    end

    test "shows Fluent In Japanese button for teachers", %{conn: conn, user: user} do
      Medoru.Repo.update!(Ecto.Changeset.change(user, type: "teacher"))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "button", "Fluent In Japanese")
    end

    test "hides Fluent In Japanese button for regular users", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      refute has_element?(view, "button", "Fluent In Japanese")
    end

    test "marks all as learned after confirmation", %{conn: conn, user: user} do
      Medoru.Repo.update!(Ecto.Changeset.change(user, type: "teacher"))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      # Click the fluent button to show confirmation
      view
      |> element("button", "Fluent In Japanese")
      |> render_click()

      assert has_element?(view, "button", "Yes, Mark Everything")

      # Click confirm
      html =
        view
        |> element("button", "Yes, Mark Everything")
        |> render_click()

      assert html =~ "Marked"
      assert html =~ "kanji and"
      assert html =~ "words as learned!"
    end

    test "toggles profile visibility", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "input[name=\"user_profile[is_public]\"]")

      # Submit with is_public unchecked
      result =
        view
        |> form("#profile-form",
          user_profile: %{display_name: user.profile.display_name, is_public: false}
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/settings/profile"}}} = result

      profile = Medoru.Accounts.get_profile_by_user!(user.id)
      assert profile.is_public == false
    end

    test "renders word meaning language preferences", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      assert has_element?(view, "span", "Word Meaning Languages")
      assert has_element?(view, "input[name=\"user_profile[show_japanese_meanings]\"]")
      assert has_element?(view, "input[name=\"user_profile[show_bulgarian_meanings]\"]")
      assert has_element?(view, "input[name=\"user_profile[show_english_meanings]\"][disabled]")
    end

    test "updates word meaning language preferences", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      result =
        view
        |> form("#profile-form",
          user_profile: %{
            display_name: user.profile.display_name,
            show_bulgarian_meanings: true
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: "/settings/profile"}}} = result

      profile = Medoru.Accounts.get_profile_by_user!(user.id)
      assert profile.show_bulgarian_meanings == true
    end

    test "checking japanese does not auto-check bulgarian", %{conn: conn, user: user} do
      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/profile")

      html =
        view
        |> form("#profile-form",
          user_profile: %{
            display_name: user.profile.display_name,
            show_japanese_meanings: "true",
            show_bulgarian_meanings: "false"
          }
        )
        |> render_change()

      refute html =~ ~r{name="user_profile\[show_bulgarian_meanings\]"[^>]*checked}
      assert html =~ ~r{name="user_profile\[show_japanese_meanings\]"[^>]*checked}
    end
  end
end
