defmodule MedoruWeb.KanjiMasterGameOverTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Challenges

  defp eligible_user_conn do
    user = user_fixture()

    for _ <- 1..50 do
      index = System.unique_integer([:positive]) |> rem(5000)

      kanji =
        kanji_fixture(%{
          character: <<0x3400 + index::utf8>>,
          stroke_count: 4,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})
    end

    {log_in_user(build_conn(), user), user}
  end

  test "game_over event reveals the panel with score and identity form" do
    {conn, _user} = eligible_user_conn()
    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    assert view
           |> render_hook("game_over", %{"score" => 123, "reason" => "lives"}) =~ "123"
  end

  test "exhausted reason shows the congratulations variant" do
    {conn, _user} = eligible_user_conn()
    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    html = render_hook(view, "game_over", %{"score" => 500, "reason" => "exhausted"})
    assert html =~ "Congratulations"
  end

  test "record_score with linked mode creates the row" do
    {conn, _user} = eligible_user_conn()
    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    render_hook(view, "game_over", %{"score" => 123, "reason" => "lives"})

    html =
      render_hook(view, "record_score", %{
        "score" => 123,
        "display_mode" => "linked"
      })

    assert html =~ "123"
    assert Challenges.leaderboard_entry_count() == 1
  end

  test "record_score anonymous with blank name shows an error" do
    {conn, _user} = eligible_user_conn()
    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    render_hook(view, "game_over", %{"score" => 50, "reason" => "lives"})

    html =
      render_hook(view, "record_score", %{
        "score" => 50,
        "display_mode" => "anonymous",
        "anonymous_name" => ""
      })

    assert html =~ "anonymous_name"
    assert Challenges.leaderboard_entry_count() == 0
  end

  test "re-recording updates the same row" do
    {conn, user} = eligible_user_conn()
    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    render_hook(view, "game_over", %{"score" => 100, "reason" => "lives"})

    render_hook(view, "record_score", %{
      "score" => 100,
      "display_mode" => "linked"
    })

    render_hook(view, "game_over", %{"score" => 150, "reason" => "lives"})

    render_hook(view, "record_score", %{
      "score" => 150,
      "display_mode" => "anonymous",
      "anonymous_name" => "KanjiKing"
    })

    assert Challenges.leaderboard_entry_count() == 1
    assert %{score: 150} = Challenges.get_rank_and_score(user.id)
  end
end
