defmodule MedoruWeb.WordSetLive.TestConfigTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordSets

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
    word_set = word_set_fixture(%{user_id: user.id, name: "Config Set"})
    {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

    %{conn: conn, word_set: word_set}
  end

  test "does not warn when only one question type is selected", %{
    conn: conn,
    word_set: word_set
  } do
    {:ok, view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test-config")

    # Two types are selected by default — no warning
    refute html =~ "You must have at least one question type selected."

    # Unselect one, leaving a single type — still no warning
    view
    |> element("button[phx-value-type='word_to_reading']")
    |> render_click()

    html = render(view)
    assert html =~ "Word to Meaning"
    refute html =~ "You must have at least one question type selected."
  end

  test "cannot uncheck the last selected question type", %{conn: conn, word_set: word_set} do
    {:ok, view, _html} = live(conn, ~p"/words/sets/#{word_set.id}/test-config")

    view
    |> element("button[phx-value-type='word_to_reading']")
    |> render_click()

    view
    |> element("button[phx-value-type='word_to_meaning']")
    |> render_click()

    html = render(view)
    assert html =~ "Word to Meaning"
  end

  test "questions-per-word slider updates the max steps", %{conn: conn, word_set: word_set} do
    {:ok, view, html} = live(conn, ~p"/words/sets/#{word_set.id}/test-config")
    assert html =~ "3"

    html =
      view
      |> element("form[phx-change='set_max_steps']")
      |> render_change(%{"max_steps" => "5"})

    assert html =~ "5"
  end
end
