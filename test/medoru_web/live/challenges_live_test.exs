defmodule MedoruWeb.ChallengesLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Challenges

  defp record(user, score, mode \\ "linked", name \\ nil) do
    {:ok, _} =
      Challenges.record_score(user, %{score: score, display_mode: mode, anonymous_name: name})
  end

  defp leaderboard_names(html) do
    # Entries render inside the top-5 list; extract display names in order.
    Regex.scan(~r/<li[^>]*>(?:[^<]*<[^>]*>)*\s*([^<]+)\s*<\/span>/, html)
  end

  test "anonymous visitors can view the page without a rank line" do
    {:ok, _view, html} = live(build_conn(), ~p"/challenges")

    assert html =~ "Learner Challenges"
    refute html =~ "Your rank"
  end

  test "renders heading and the Kanji Master card" do
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges")

    assert html =~ "Learner Challenges"
    assert html =~ "Kanji Master"
  end

  test "card shows top 5 in descending order and hides the 6th" do
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    users = for _ <- 1..6, do: user_fixture()

    users
    |> Enum.with_index(1)
    |> Enum.each(fn {u, i} -> record(u, i * 10) end)

    {:ok, _view, html} = live(conn, ~p"/challenges")

    # highest score first
    assert html =~ "60"
    assert html =~ "10"
    refute html =~ "\">6</"

    # order check: 60 appears before 50 etc. within the leaderboard list
    [i60, i50, i40] =
      for pat <- [~r/>60</, ~r/>50</, ~r/>40</] do
        [{idx, _}] = Regex.run(pat, html, return: :index)
        idx
      end

    assert i60 < i50 and i50 < i40
  end

  test "linked entries link to the profile, anonymous render plain" do
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    linked = user_fixture_with_profile()
    {:ok, profile} = Medoru.Accounts.update_profile(linked.profile, %{display_name: "LinkedNick"})
    assert profile.display_name == "LinkedNick"
    record(linked, 100, "linked")
    anon = user_fixture()
    record(anon, 90, "anonymous", "AnonName")

    {:ok, _view, html} = live(conn, ~p"/challenges")

    assert html =~ ~r|/users/#{linked.id}|
    assert html =~ "LinkedNick"
    assert html =~ "AnonName"
    refute html =~ ~r|/users/#{anon.id}|
  end

  test "logged-in user outside top 5 sees their rank" do
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    for _ <- 1..5, do: user_fixture() |> then(fn u -> record(u, 500) end)
    record(user, 10)

    {:ok, _view, html} = live(conn, ~p"/challenges")

    assert html =~ "#6"
  end

  test "user with no score sees no rank line" do
    user = user_fixture()
    conn = log_in_user(build_conn(), user)

    {:ok, _view, html} = live(conn, ~p"/challenges")

    refute html =~ "Your rank"
  end
end
