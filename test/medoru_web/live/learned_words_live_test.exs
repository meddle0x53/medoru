defmodule MedoruWeb.LearnedWordsLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.Learning

  test "lists regular learned words for Japanese learners", %{conn: conn} do
    user = user_fixture(%{learning_language: "japanese"})
    word = word_fixture()
    {:ok, _} = Learning.track_word_learned(user.id, word.id)
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/users/#{user.id}/words")

    assert html =~ "Learned Words"
    assert html =~ word.text
    assert html =~ word.reading
    assert html =~ word.meaning
  end

  test "lists English-learning learned words for English learners", %{conn: conn} do
    user = user_fixture(%{learning_language: "english"})
    word = word_fixture()
    {:ok, _} = Learning.track_english_word_learned(user.id, word.id)
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/users/#{user.id}/words")

    assert html =~ "Learned Words"
    assert html =~ word.text
    assert html =~ word.reading
    assert html =~ word.meaning
  end

  test "paginates learned words", %{conn: conn} do
    user = user_fixture(%{learning_language: "japanese"})

    for _i <- 1..35 do
      word = word_fixture()
      {:ok, _} = Learning.track_word_learned(user.id, word.id)
    end

    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/words")
    assert render(view) =~ "Page 1 of 2"

    view
    |> element("button", "Next")
    |> render_click()

    assert render(view) =~ "Page 2 of 2"
  end
end
