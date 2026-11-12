defmodule MedoruWeb.SettingsLive.LanguageTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts

  describe "set_locale event" do
    test "persists locale to the logged-in user's profile", %{conn: conn} do
      user = user_fixture_with_registration()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/language")

      render_click(view, "set_locale", %{"locale" => "bg"})

      assert Accounts.get_user_profile(user.id).locale == "bg"
      assert render(view) =~ "Български"
    end

    test "rejects unsupported locale", %{conn: conn} do
      user = user_fixture_with_registration()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/settings/language")

      render_click(view, "set_locale", %{"locale" => "fr"})

      assert Accounts.get_user_profile(user.id).locale == "en"
      assert render(view) =~ "Invalid language selection."
    end
  end
end
