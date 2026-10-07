defmodule MedoruWeb.KanjiMasterGuardTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  # Anonymous users must not crash the LiveView when pushing record_score;
  # malformed scores must be ignored gracefully.

  test "anonymous visitor pushing record_score does not crash the view" do
    {:ok, view, _html} = live(build_conn(), ~p"/challenges/kanji-master")

    html =
      render_hook(view, "record_score", %{
        "score" => 100,
        "display_mode" => "linked"
      })

    assert html =~ "Kanji Master"
  end

  test "game_over with a non-numeric score does not crash the view" do
    conn = build_conn()

    # log in an eligible user so we reach the game shell
    user = Medoru.AccountsFixtures.user_fixture()

    for _ <- 1..50 do
      index = System.unique_integer([:positive]) |> rem(5000)

      {:ok, kanji} =
        Medoru.Content.create_kanji(%{
          character: <<0x3400 + index::utf8>>,
          meanings: ["m"],
          stroke_count: 4,
          jlpt_level: 5,
          frequency: 100,
          radicals: [],
          components: [],
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      Medoru.Learning.track_kanji_learned(user.id, kanji.id)
    end

    conn = Phoenix.ConnTest.init_test_session(conn, %{})
    conn = Plug.Conn.put_session(conn, :user_id, user.id)

    {:ok, view, _html} = live(conn, ~p"/challenges/kanji-master")

    html = render_hook(view, "game_over", %{"score" => "not-a-number", "reason" => "lives"})
    assert html =~ ~s|id="kanji-master-game"|
  end
end
