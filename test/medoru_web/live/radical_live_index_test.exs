defmodule MedoruWeb.RadicalLive.IndexTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  test "radical index shows DB classical-radical counts", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    kanji_fixture(%{character: "監", radicals: ["皿"], components: ["皿"], frequency: 408})
    kanji_fixture(%{character: "益", radicals: ["皿"], components: ["水", "皿"], frequency: 674})
    kanji_fixture(%{character: "求", radicals: ["水"], components: ["水"], frequency: 220})

    {:ok, _view, html} = live(conn, ~p"/radicals")

    # 皿 has 2 kanji classified under it, 水 has 1
    assert html =~ "2 kanji"
    assert html =~ "1 kanji"
    # sorted by count desc: 皿 (2) before 水 (1)
    assert :binary.match(html, "皿") < :binary.match(html, "水")
  end

  test "filter by kanji shows its classical radicals", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    kanji_fixture(%{character: "益", radicals: ["皿"], components: ["水", "皿"]})
    kanji_fixture(%{character: "求", radicals: ["水"], components: ["水"]})

    {:ok, view, _html} = live(conn, ~p"/radicals")

    html =
      view
      |> element("form[phx-change='filter']")
      |> render_change(%{"q" => "益"})

    assert html =~ "益 is classified under:"
    assert html =~ "皿"
    refute html =~ "求"

    html = render(view)
    assert html =~ "皿"
    refute html =~ "求"
  end

  test "filter by radical variant or meaning", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/radicals")

    html =
      view
      |> element("form[phx-change='filter']")
      |> render_change(%{"q" => "氵"})

    assert html =~ "水"

    html =
      view
      |> element("form[phx-change='filter']")
      |> render_change(%{"q" => "water"})

    assert html =~ "水"
  end

  test "clear filter restores the full list", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/radicals?q=益")

    html =
      view
      |> element("button[phx-click='clear_filter']")
      |> render_click()

    assert html =~ "radicals"
  end
end
