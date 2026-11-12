defmodule MedoruWeb.Plugs.SetLocaleTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.Accounts

  test "anonymous user with locale cookie gets cookie locale", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("medoru_locale", "bg")
      |> get(~p"/")

    assert conn.assigns[:locale] == "bg"
    assert get_session(conn, :locale) == "bg"
  end

  test "logged-in user gets locale from their profile, not the cookie", %{conn: conn} do
    user = user_fixture_with_registration()
    {:ok, profile} = Accounts.update_profile(user.profile, %{locale: "ja"})

    conn =
      conn
      |> log_in_user(%{user | profile: profile})
      |> put_req_cookie("medoru_locale", "bg")
      |> get(~p"/dashboard")

    assert conn.assigns[:locale] == "ja"
    assert get_session(conn, :locale) == "ja"
    assert conn.assigns[:current_scope].locale == "ja"
  end

  test "logged-in user passing ?locale= gets that locale and it is persisted to the profile",
       %{conn: conn} do
    user = user_fixture_with_registration()
    Accounts.update_profile(user.profile, %{locale: "ja"})

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/dashboard?locale=bg")

    assert conn.assigns[:locale] == "bg"
    assert Accounts.get_user_profile(user.id).locale == "bg"
  end

  test "anonymous user falls back to Accept-Language", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept-language", "bg-BG,bg;q=0.9,en;q=0.8")
      |> get(~p"/")

    assert conn.assigns[:locale] == "bg"
  end

  test "anonymous user defaults to en", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert conn.assigns[:locale] == "en"
  end
end
