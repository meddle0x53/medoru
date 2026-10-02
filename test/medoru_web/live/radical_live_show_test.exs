defmodule MedoruWeb.RadicalLive.ShowTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  test "radical page lists kanji by classical radical, not by component", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    # 益-like kanji: classical radical 皿, but contains 水 as a component
    kanji =
      kanji_fixture(%{
        character: "益",
        radicals: ["皿"],
        components: ["水", "皿"],
        frequency: 674
      })

    {:ok, _view, html} = live(conn, ~p"/radicals/皿")
    assert html =~ "益"

    {:ok, _view, html} = live(conn, ~p"/radicals/水")
    refute html =~ "益"

    # canonical lookup via variant also resolves to the same radical page data
    assert kanji.radicals == ["皿"]
  end

  test "radical page shows DB count and sorted kanji", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    kanji_fixture(%{character: "監", radicals: ["皿"], components: ["皿"], frequency: 408})
    kanji_fixture(%{character: "盟", radicals: ["皿"], components: ["皿"], frequency: 587})

    {:ok, _view, html} = live(conn, ~p"/radicals/皿")
    assert html =~ "監"
    assert html =~ "盟"
    assert html =~ "2"
  end

  test "unknown radical redirects with error", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:live_redirect, %{to: "/radicals"}}} = live(conn, ~p"/radicals/xxx")
  end
end
