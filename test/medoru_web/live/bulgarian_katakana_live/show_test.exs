defmodule MedoruWeb.BulgarianKatakanaLive.ShowTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders letter details with readings and words", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/Б")

    assert html =~ "Б"
    assert html =~ "ブ"
    assert html =~ "ぶ"
    assert html =~ "bu"
    assert html =~ ~s(<span class="text-accent font-bold">Б</span>лагодаря)
    assert html =~ "ブラゴダリャ"
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

  test "highlights the current Bulgarian letter in example words", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/Й")

    assert html =~ ~s(<span class="text-accent font-bold">Й</span>ога)
    assert html =~ ~s(Ма<span class="text-accent font-bold">й</span>)
    assert html =~ ~s(Ча<span class="text-accent font-bold">й</span>)
    assert html =~ ~s(Ха<span class="text-accent font-bold">й</span>де)
    assert html =~ ~s(Здраве<span class="text-accent font-bold">й</span>)
  end

  test "links example words that match by conjugation", %{conn: conn} do
    word = word_fixture(%{text: "行く", reading: "いく", word_type: :verb})
    word_conjugation_fixture(%{word: word, conjugated_form: "行こう"})

    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/Й")

    assert html =~ ~p"/words/#{word.id}"
    assert html =~ ~s(Ха<span class="text-accent font-bold">й</span>де)
  end

  test "links example words that match by Japanese reading", %{conn: conn} do
    evening_word = word_fixture(%{text: "今晩は", reading: "こんばんは"})
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/Д")

    assert html =~ ~p"/words/#{evening_word.id}"
    assert html =~ ~s(<span class="text-accent font-bold">Д</span>обър вечер)

    greeting_word = word_fixture(%{text: "今日は", reading: "こんにちは"})
    {:ok, _view, html} = live(conn, ~p"/katakana/bulgarian/З")

    assert html =~ ~p"/words/#{greeting_word.id}"
    assert html =~ ~s(<span class="text-accent font-bold">З</span>дравей)
  end
end
