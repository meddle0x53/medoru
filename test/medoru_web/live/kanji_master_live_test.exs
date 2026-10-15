defmodule MedoruWeb.KanjiMasterLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  @classroom_url "/classrooms/36904ffe-0f2d-4fab-b578-652752cf5c27"

  defp unique_char do
    index = System.unique_integer([:positive]) |> rem(5000)
    <<0x3400 + index::utf8>>
  end

  defp learn_kanji(user, n, stroke_count \\ 4) do
    for _ <- 1..n do
      kanji =
        kanji_fixture(%{
          character: unique_char(),
          stroke_count: stroke_count,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})
    end
  end

  test "anonymous visitor sees the gate with a sign-in prompt" do
    {:ok, _view, html} = live(build_conn(), ~p"/challenges/kanji-master")

    assert html =~ "Kanji Master"
    assert html =~ ~r|/users/log-in|
    refute html =~ ~s|id="kanji-master-game"|
  end

  test "user with 49 learned kanji sees the gate with practice links" do
    user = user_fixture()
    learn_kanji(user, 49)
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master")

    assert html =~ "/kanji"
    assert html =~ "/the-hollow-ouroboros"
    assert html =~ @classroom_url
    refute html =~ ~s|id="kanji-master-game"|
  end

  test "user with 50 learned kanji sees the game shell with resources and pool" do
    user = user_fixture()
    learn_kanji(user, 50)
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master")

    assert html =~ ~s|id="kanji-master-game"|
    assert html =~ ~s|data-start-lives="20"|
    assert html =~ ~s|data-start-hints="5"|
    assert html =~ ~s|data-start-coins=|
    assert html =~ "km-lives"
    assert html =~ "km-coins"
    assert html =~ "km-hints"
  end

  test "eligible user gets whole-dictionary boss kanji (22+ strokes) in data-boss-pool" do
    user = user_fixture()
    learn_kanji(user, 50)

    boss_char = <<0x9B31::utf8>>

    _boss =
      kanji_fixture(%{
        character: boss_char,
        stroke_count: 22,
        stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
      })

    conn = log_in_user(build_conn(), user)
    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master")

    assert html =~ ~s|data-boss-pool=|
    assert html =~ boss_char
    refute html =~ "data-boss-pool=\"[]\""
  end

  test "boss pool falls back to the highest-stroke kanji when none have 22+" do
    user = user_fixture()
    learn_kanji(user, 50)

    fallback_char = <<0x9B32::utf8>>

    _fallback =
      kanji_fixture(%{
        character: fallback_char,
        stroke_count: 17,
        stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
      })

    conn = log_in_user(build_conn(), user)
    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master")

    assert html =~ ~s|data-boss-pool=|
    assert html =~ fallback_char
  end

  test "game shell renders the boss label element and boss label data attribute" do
    user = user_fixture()
    learn_kanji(user, 50)
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges/kanji-master")

    assert html =~ ~s|id="km-boss-label"|
    assert html =~ ~s|data-boss-label=|
  end
end
