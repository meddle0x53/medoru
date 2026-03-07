defmodule MedoruWeb.KanjiLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.ContentFixtures
  import Medoru.AccountsFixtures

  describe "Index" do
    setup [:create_kanji]

    test "lists all kanji by JLPT level", %{conn: conn, kanji: kanji} do
      {:ok, _view, html} = live(conn, ~p"/kanji")

      assert html =~ "Kanji Browser"
      assert html =~ kanji.character
      assert html =~ "JLPT N5"
    end

    test "filters kanji by JLPT level", %{conn: conn} do
      n5_kanji = kanji_fixture(%{jlpt_level: 5, character: unique_kanji_char()})
      n4_kanji = kanji_fixture(%{jlpt_level: 4, character: unique_kanji_char()})

      {:ok, view, _html} = live(conn, ~p"/kanji?level=4")

      assert render(view) =~ n4_kanji.character
      refute render(view) =~ n5_kanji.character
    end

    test "shows kanji count", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/kanji")

      html = render(view)
      assert html =~ "characters"
    end

    test "level selector is present", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/kanji")

      # Check for N1-N5 buttons
      assert html =~ "N1"
      assert html =~ "N2"
      assert html =~ "N3"
      assert html =~ "N4"
      assert html =~ "N5"
    end

    test "navigates to kanji detail page", %{conn: conn, kanji: kanji} do
      {:ok, view, _html} = live(conn, ~p"/kanji")

      # Click on a kanji card
      view
      |> element("a[href=\"/kanji/#{kanji.id}\"]")
      |> render_click()

      assert_redirect(view, ~p"/kanji/#{kanji.id}")
    end

    test "shows empty state when no kanji", %{conn: conn} do
      # Use a level that has no kanji (N1-N3 in our seed data)
      {:ok, _view, html} = live(conn, ~p"/kanji?level=1")

      assert html =~ "No kanji found"
    end
  end

  describe "Show" do
    setup [:create_kanji_with_readings]

    test "displays kanji details", %{conn: conn, kanji: kanji} do
      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ kanji.character
      assert html =~ hd(kanji.meanings)
      assert html =~ "#{kanji.stroke_count} strokes"
      assert html =~ "JLPT N#{kanji.jlpt_level}"
    end

    test "displays on'yomi readings", %{conn: conn, kanji: kanji} do
      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "On"
      assert html =~ "Chinese reading"

      on_reading = Enum.find(kanji.kanji_readings, &(&1.reading_type == :on))
      assert html =~ on_reading.reading
      assert html =~ on_reading.romaji
    end

    test "displays kun'yomi readings", %{conn: conn, kanji: kanji} do
      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "Kun"
      assert html =~ "Japanese reading"

      kun_reading = Enum.find(kanji.kanji_readings, &(&1.reading_type == :kun))
      assert html =~ kun_reading.reading
      assert html =~ kun_reading.romaji
    end

    test "has back link to kanji list", %{conn: conn, kanji: kanji} do
      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "Back to N#{kanji.jlpt_level} Kanji"
    end

    test "navigates back to kanji list", %{conn: conn, kanji: kanji} do
      {:ok, view, _html} = live(conn, ~p"/kanji/#{kanji.id}")

      view
      |> element("a", "Back to N#{kanji.jlpt_level} Kanji")
      |> render_click()

      assert_redirect(view, ~p"/kanji?level=#{kanji.jlpt_level}")
    end

    test "shows radicals if present", %{conn: conn} do
      kanji = kanji_fixture(%{radicals: ["日", "月"], character: unique_kanji_char()})

      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "Radicals"
      assert html =~ "日"
      assert html =~ "月"
    end

    test "shows frequency if present", %{conn: conn} do
      kanji = kanji_fixture(%{frequency: 50, character: unique_kanji_char()})

      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "50"
    end

    test "shows 'Mark as Learned' button for authenticated users", %{conn: conn} do
      user = user_fixture_with_registration()
      conn = log_in_user(conn, user)

      kanji = kanji_fixture(%{character: unique_kanji_char()})

      {:ok, _view, html} = live(conn, ~p"/kanji/#{kanji.id}")

      assert html =~ "Mark as Learned"
    end

    test "returns 404 for non-existent kanji", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/kanji/#{Ecto.UUID.generate()}")
      end
    end
  end

  describe "authenticated navigation" do
    setup %{conn: conn} do
      user = user_fixture_with_registration()
      %{conn: log_in_user(conn, user)}
    end

    test "shows kanji link in navigation when authenticated", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Kanji"
    end
  end

  # Setup helpers

  defp create_kanji(_) do
    kanji = kanji_fixture(%{character: unique_kanji_char()})
    %{kanji: kanji}
  end

  defp create_kanji_with_readings(_) do
    kanji =
      kanji_with_readings_fixture(
        %{character: unique_kanji_char()},
        [
          %{reading_type: :on, reading: "テスト", romaji: "tesuto"},
          %{reading_type: :kun, reading: "てすと", romaji: "tesuto"}
        ]
      )

    %{kanji: kanji}
  end

  defp unique_kanji_char do
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end
end
