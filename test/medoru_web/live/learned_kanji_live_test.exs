defmodule MedoruWeb.LearnedKanjiLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.Learning

  describe "Practice form" do
    test "renders learned kanji and selection UI", %{conn: conn} do
      user = user_fixture()
      kanji = kanji_fixture()
      {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/users/#{user.id}/kanji/practice")

      assert html =~ "Practice Kanji"
      assert html =~ kanji.character
      assert html =~ "0 / 20 selected"
    end

    test "paginates learned kanji", %{conn: conn} do
      user = user_fixture()

      for i <- 1..35 do
        kanji = kanji_fixture(%{character: unique_kanji_char(i)})
        {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      end

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji/practice")
      assert render(view) =~ "Page 1 of 2"

      view
      |> element("button", "Next")
      |> render_click()

      assert render(view) =~ "Page 2 of 2"
    end

    test "selection persists across pages", %{conn: conn} do
      user = user_fixture()

      kanji_ids =
        for i <- 1..35 do
          kanji = kanji_fixture(%{character: unique_kanji_char(i)})
          {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
          kanji.id
        end

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji/practice")

      [first_id | _rest] = kanji_ids

      # Select first kanji on page 1
      view
      |> element("div[phx-click='toggle_select'][phx-value-id='select-kanji-#{first_id}']")
      |> render_click()

      assert render(view) =~ "1 / 20 selected"

      # Go to next page
      view
      |> element("button", "Next")
      |> render_click()

      assert render(view) =~ "Page 2 of 2"
      assert render(view) =~ "1 / 20 selected"

      # Return to first page
      view
      |> element("button", "Prev")
      |> render_click()

      assert render(view) =~ "Page 1 of 2"
      assert render(view) =~ "1 / 20 selected"
    end
  end

  defp unique_kanji_char(index) do
    # Use CJK Unified Ideographs Extension A range (U+3400 to U+4DBF)
    # spaced apart to avoid collisions with the fixture generator
    <<0x3400 + index::utf8>>
  end
end
