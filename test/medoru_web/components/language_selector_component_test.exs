defmodule MedoruWeb.LanguageSelectorComponentTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts

  # The selector persists the locale server-side and triggers a client-side
  # reload of the CURRENT url (window.location.reload via the "reload_page"
  # event), so the user stays on whatever page they were on — the old
  # `~p"/?locale=..."` links that redirected to "/" are gone.
  test "logged-in user can switch locale from the top bar on any page", %{conn: conn} do
    user = user_fixture_with_registration()

    {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/kanji")

    assert html =~ "language-selector"

    view
    |> element("#language-selector button[phx-value-locale='bg']")
    |> render_click()

    assert Accounts.get_user_profile(user.id).locale == "bg"

    # The dropdown now shows the new locale as active
    assert render(view) =~ ~s(data-active-locale="bg")
  end

  test "anonymous user can switch locale from the top bar without a profile", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/kanji")

    assert has_element?(view, "#language-selector-anon")

    # Must not raise even though there is no logged-in user / profile
    view
    |> element("#language-selector-anon button[phx-value-locale='ja']")
    |> render_click()

    assert render(view) =~ ~s(data-active-locale="ja")
  end
end
