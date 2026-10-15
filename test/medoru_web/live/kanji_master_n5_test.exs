defmodule MedoruWeb.KanjiMasterN5Test do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Challenges

  defp unique_char do
    index = System.unique_integer([:positive]) |> rem(5000)
    <<0x3400 + index::utf8>>
  end

  defp n5_kanji do
    kanji_fixture(%{
      character: unique_char(),
      stroke_count: 4,
      jlpt_level: 5,
      stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
    })
  end

  test "anonymous visitor gets the game shell (no gate) with 10 coins and the N5 pool" do
    kanji = n5_kanji()

    {:ok, _view, html} = live(build_conn(), ~p"/challenges/kanji-master/n5")

    assert html =~ ~s|id="kanji-master-game"|
    assert html =~ ~s|data-start-coins="10"|
    assert html =~ kanji.character
    refute html =~ "You need at least 50 learned kanji"
  end

  test "logged-in user with fewer than 50 learned kanji also gets the shell with 10 coins" do
    n5_kanji()
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master/n5")

    assert html =~ ~s|id="kanji-master-game"|
    assert html =~ ~s|data-start-coins="10"|
  end

  test "anonymous record_score creates a named n5 entry and upserts by name" do
    n5_kanji()
    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n5")

    render_hook(view, "game_over", %{"score" => 42, "reason" => "lives"})

    html =
      render_hook(view, "record_score", %{
        "score" => 42,
        "anonymous_name" => "wanderer"
      })

    assert html =~ "wanderer"
    assert Challenges.leaderboard_entry_count("n5") == 1

    # Replay with the same name keeps the higher score and stays one row.
    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n5")
    render_hook(view, "game_over", %{"score" => 100, "reason" => "lives"})

    render_hook(view, "record_score", %{
      "score" => 100,
      "anonymous_name" => "wanderer"
    })

    assert Challenges.leaderboard_entry_count("n5") == 1
    assert [%{score: 100, anonymous_name: "wanderer"}] = Challenges.get_leaderboard("n5")
  end

  test "anonymous record_score refuses empty and over-long names" do
    n5_kanji()
    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n5")
    render_hook(view, "game_over", %{"score" => 42, "reason" => "lives"})

    html =
      render_hook(view, "record_score", %{"score" => 42, "anonymous_name" => "   "})

    assert html =~ "anonymous_name"
    assert Challenges.leaderboard_entry_count("n5") == 0

    html =
      render_hook(view, "record_score", %{
        "score" => 42,
        "anonymous_name" => "thirteenchars"
      })

    assert html =~ "anonymous_name"
    assert Challenges.leaderboard_entry_count("n5") == 0
  end

  test "master and n5 leaderboards are separate" do
    n5_kanji()
    user = user_fixture()

    assert {:ok, _} =
             Challenges.record_score(user, %{score: 300, display_mode: "linked", mode: "master"})

    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master/n5")
    render_hook(view, "game_over", %{"score" => 10, "reason" => "lives"})

    render_hook(view, "record_score", %{"score" => 10, "anonymous_name" => "rookie"})

    assert [%{score: 300}] = Challenges.get_leaderboard("master")
    assert [%{score: 10, anonymous_name: "rookie"}] = Challenges.get_leaderboard("n5")
    assert Challenges.get_rank_and_score(user.id, "master").score == 300
    assert Challenges.get_rank_and_score(user.id, "n5") == nil
  end
end
