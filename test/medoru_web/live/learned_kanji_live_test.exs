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

  describe "Index with search, filter, and sort" do
    test "searches learned kanji and clears the search", %{conn: conn} do
      user = user_fixture()
      k1 = kanji_fixture(%{character: "日"})
      k2 = kanji_fixture(%{character: "月"})
      {:ok, _} = Learning.track_kanji_learned(user.id, k1.id)
      {:ok, _} = Learning.track_kanji_learned(user.id, k2.id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji")

      assert render(view) =~ "日"
      assert render(view) =~ "月"

      html =
        view
        |> form("#search-form", %{query: "日"})
        |> render_submit()

      assert html =~ "日"
      refute html =~ "月"

      html =
        view
        |> element("button", "Clear")
        |> render_click()

      assert html =~ "日"
      assert html =~ "月"
    end

    test "filters learned kanji by JLPT level", %{conn: conn} do
      user = user_fixture()
      n5 = kanji_fixture(%{character: "山", jlpt_level: 5})
      n4 = kanji_fixture(%{character: "川", jlpt_level: 4})
      {:ok, _} = Learning.track_kanji_learned(user.id, n5.id)
      {:ok, _} = Learning.track_kanji_learned(user.id, n4.id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji?level=4")

      html = render(view)
      refute html =~ "山"
      assert html =~ "川"
      assert html =~ "JLPT N4"
    end

    test "sorts learned kanji by character", %{conn: conn} do
      user = user_fixture()
      k1 = kanji_fixture(%{character: "火"})
      k2 = kanji_fixture(%{character: "水"})
      {:ok, _} = Learning.track_kanji_learned(user.id, k1.id)
      {:ok, _} = Learning.track_kanji_learned(user.id, k2.id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji")

      html =
        view
        |> form("#sort-form", %{sort: "character_asc"})
        |> render_change()

      # Unicode ascending: 水 (U+6C34) comes before 火 (U+706B)
      assert html =~ ~r/水.*火/s
    end

    test "paginates with an active filter", %{conn: conn} do
      user = user_fixture()

      for i <- 1..35 do
        kanji = kanji_fixture(%{character: unique_kanji_char(i), jlpt_level: 5})
        {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      end

      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/kanji?level=5")

      assert render(view) =~ "Page 1 of 2"

      view
      |> element("button", "Next")
      |> render_click()

      assert render(view) =~ "Page 2 of 2"
    end
  end

  describe "Practice challenge" do
    test "displays kanji readings during practice", %{conn: conn} do
      user = user_fixture()
      kanji = kanji_with_readings_fixture()
      {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      conn = log_in_user(conn, user)

      {:ok, _view, html} =
        live(conn, ~p"/users/#{user.id}/kanji/practice/challenge?ids=#{kanji.id}")

      assert html =~ "Kanji Practice"
      assert html =~ kanji.character
      assert html =~ "テスト"
      assert html =~ "てすと"
    end

    test "shows readings with the lowest admin-defined position first", %{conn: conn} do
      user = user_fixture()
      kanji = kanji_fixture()

      kanji_reading_fixture(kanji.id, %{
        reading_type: :on,
        reading: "カター",
        romaji: "kataa",
        position: 2
      })

      kanji_reading_fixture(kanji.id, %{
        reading_type: :on,
        reading: "アター",
        romaji: "ataa",
        position: 0
      })

      kanji_reading_fixture(kanji.id, %{
        reading_type: :kun,
        reading: "あと",
        romaji: "ato",
        position: 3
      })

      kanji_reading_fixture(kanji.id, %{
        reading_type: :kun,
        reading: "さき",
        romaji: "saki",
        position: 1
      })

      {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      conn = log_in_user(conn, user)

      {:ok, _view, html} =
        live(conn, ~p"/users/#{user.id}/kanji/practice/challenge?ids=#{kanji.id}")

      assert html =~ "アター"
      assert html =~ "さき"
      refute html =~ "カター"
      refute html =~ "あと"
    end

    test "shows a word hint for the current kanji", %{conn: conn} do
      user = user_fixture()
      kanji = kanji_fixture()

      reading =
        kanji_reading_fixture(kanji.id, %{
          reading_type: :on,
          reading: "テスト",
          romaji: "tesuto"
        })

      {:ok, _word} =
        Medoru.Content.create_word_with_kanji(
          %{
            text: kanji.character <> <<0x3901::utf8>>,
            reading: "てすと",
            meaning: "hint word meaning",
            difficulty: 5,
            usage_frequency: 10,
            word_type: :noun
          },
          [%{position: 0, kanji_id: kanji.id, kanji_reading_id: reading.id}]
        )

      {:ok, _} = Learning.track_kanji_learned(user.id, kanji.id)
      conn = log_in_user(conn, user)

      {:ok, _view, html} =
        live(conn, ~p"/users/#{user.id}/kanji/practice/challenge?ids=#{kanji.id}")

      assert html =~ "hint word meaning"
      assert html =~ "てすと"
    end
  end

  defp unique_kanji_char(index) do
    # Use CJK Unified Ideographs Extension A range (U+3400 to U+4DBF)
    # spaced apart to avoid collisions with the fixture generator
    <<0x3400 + index::utf8>>
  end
end
