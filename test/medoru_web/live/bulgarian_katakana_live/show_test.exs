defmodule MedoruWeb.BulgarianKatakanaLive.ShowTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders letter details with readings and words", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/Б")

    assert html =~ "Б"
    assert html =~ "ブ"
    assert html =~ "ぶ"
    assert html =~ "bu"
    assert html =~ "Банан"
    assert html =~ "バナン"
  end

  test "renders navigation to previous and next letters", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/В")

    assert html =~ URI.encode("/katakana/bulgarian/Б")
    assert html =~ URI.encode("/katakana/bulgarian/Г")
  end

  test "redirects for an unknown letter", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/katakana/bulgarian"}}} =
             live(conn, ~p"/katakana/bulgarian/!@#")
  end
end
