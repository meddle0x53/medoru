defmodule MedoruWeb.BulgarianKatakanaLive.IndexTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the Bulgarian katakana index page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian")

    assert html =~ "Bulgarian Katakana"
    assert html =~ "А"
    assert html =~ "Я"
    assert html =~ "Back to Katakana"
  end

  test "links each letter to its detail page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian")

    assert html =~ URI.encode("/katakana/bulgarian/Б")
    assert html =~ URI.encode("/katakana/bulgarian/Я")
  end
end
