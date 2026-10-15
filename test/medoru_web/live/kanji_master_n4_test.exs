defmodule MedoruWeb.KanjiMasterN4Test do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.ContentFixtures

  alias Medoru.Challenges

  defp unique_char do
    index = System.unique_integer([:positive]) |> rem(5000)
    <<0x3400 + index::utf8>>
  end

  defp n4_kanji do
    kanji_fixture(%{
      character: unique_char(),
      stroke_count: 8,
      jlpt_level: 4,
      stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
    })
  end

  test "anonymous visitor gets the game shell (no gate) with 10 coins and the N4 pool" do
    kanji = n4_kanji()

    {:ok, _view, html} = live(build_conn(), ~p"/challenges/kanji-master/n4")

    assert html =~ ~s|id="kanji-master-game"|
    assert html =~ ~s|data-start-coins="10"|
    assert html =~ kanji.character
    refute html =~ "You need at least 50 learned kanji"
  end

  test "anonymous record_score keeps the higher score per name" do
    n4_kanji()
    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n4")
    render_hook(view, "game_over", %{"score" => 30, "reason" => "lives"})

    render_hook(view, "record_score", %{"score" => 30, "anonymous_name" => "rookie"})

    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n4")
    render_hook(view, "game_over", %{"score" => 80, "reason" => "lives"})

    render_hook(view, "record_score", %{"score" => 80, "anonymous_name" => "rookie"})

    assert Challenges.leaderboard_entry_count("n4") == 1
    assert [%{score: 80, anonymous_name: "rookie"}] = Challenges.get_leaderboard("n4")
  end

  test "n4 leaderboard is separate from n5 and master" do
    n4_kanji()

    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n4")
    render_hook(view, "game_over", %{"score" => 5, "reason" => "lives"})
    render_hook(view, "record_score", %{"score" => 5, "anonymous_name" => "rookie"})

    assert [%{score: 5}] = Challenges.get_leaderboard("n4")
    assert Challenges.get_leaderboard("n5") == []
    assert Challenges.get_leaderboard("master") == []
  end
end
