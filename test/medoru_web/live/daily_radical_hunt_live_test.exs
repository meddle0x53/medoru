defmodule MedoruWeb.DailyRadicalHuntLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.Learning

  defp setup_challenge(_) do
    user = user_fixture()

    for char <- ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"] do
      kanji_fixture(%{character: char, radicals: ["口"]})
    end

    seed_kanji = kanji_fixture(%{character: "中", radicals: ["口"]})
    {:ok, _} = Learning.track_kanji_learned(user.id, seed_kanji.id)

    %{user: user, seed_kanji: seed_kanji}
  end

  describe "mount" do
    setup [:setup_challenge]

    test "shows already completed state", %{conn: conn, user: user} do
      Learning.complete_daily_challenge(user.id, "daily_radical_hunt", 80, score: 1)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/radical-hunt")

      assert html =~ "Already Completed"
    end

    test "shows ready screen with radical and kanji count", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/radical-hunt")

      assert html =~ "Daily Radical Hunt"
      assert html =~ "口"
      assert html =~ "30 XP per kanji"
    end

    test "handles device_info hook from GameFullscreen", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/daily-challenges/radical-hunt")

      assert render_hook(view, "device_info", %{"is_mobile" => false}) =~ "Daily Radical Hunt"
    end
  end

  describe "gameplay" do
    setup [:setup_challenge]

    test "submits correct kanji and ends game", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/daily-challenges/radical-hunt")

      view
      |> element("button", "Start Game")
      |> render_click()

      assert render(view) =~ "found"

      view
      |> form("form", %{"kanji" => "中"})
      |> render_submit()

      html = render(view)
      assert html =~ "Correct!"
      assert html =~ "中"

      # Advance timer to end the game
      for _ <- 1..2 do
        for _ <- 1..60 do
          send(view.pid, :tick)
        end
      end

      html = render(view)

      assert html =~ "kanji found"
      assert html =~ "80 XP"
    end
  end
end
