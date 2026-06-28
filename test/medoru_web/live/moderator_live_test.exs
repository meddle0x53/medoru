defmodule MedoruWeb.ModeratorLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "Moderator dashboard" do
    test "moderator can access dashboard", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_moderator(user, true)

      {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/moderator")

      assert html =~ "Moderator Dashboard"
      assert has_element?(view, "a[href=\"/moderator/kanji\"]")
      assert has_element?(view, "a[href=\"/moderator/words\"]")
    end

    test "admin can access moderator dashboard", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_type(user, "admin")

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/moderator")
      assert html =~ "Moderator Dashboard"
    end

    test "non-moderator is redirected from dashboard", %{conn: conn} do
      user = user_fixture_with_registration()

      {:error, {:redirect, %{to: "/dashboard"}}} =
        conn |> log_in_user(user) |> live(~p"/moderator")
    end

    test "moderator can access /moderator/words", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_moderator(user, true)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/moderator/words")
      assert html =~ "Words"
    end

    test "moderator can access /moderator/kanji", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_moderator(user, true)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/moderator/kanji")
      assert html =~ "Kanji"
    end

    test "moderator kanji edit shows add reading form", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_moderator(user, true)
      kanji = kanji_fixture(%{character: "日"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/moderator/kanji/#{kanji.id}/edit")

      refute render(view) =~ "Add New Reading"

      html =
        view
        |> element("button[phx-click='show_new_reading']")
        |> render_click()

      assert html =~ "Add New Reading"
      assert html =~ "name=\"reading[reading]\""
    end

    test "non-moderator is redirected from /moderator/words", %{conn: conn} do
      user = user_fixture_with_registration()

      {:error, {:redirect, %{to: "/dashboard"}}} =
        conn |> log_in_user(user) |> live(~p"/moderator/words")
    end

    test "moderator can access /moderator/grammars", %{conn: conn} do
      user = user_fixture_with_registration()
      {:ok, user} = Medoru.Accounts.update_user_moderator(user, true)

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/moderator/grammars")
      assert html =~ "Grammar Management"
    end

    test "non-moderator is redirected from /moderator/grammars", %{conn: conn} do
      user = user_fixture_with_registration()

      {:error, {:redirect, %{to: "/dashboard"}}} =
        conn |> log_in_user(user) |> live(~p"/moderator/grammars")
    end
  end
end
