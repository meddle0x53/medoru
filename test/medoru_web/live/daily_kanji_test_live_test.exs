defmodule MedoruWeb.DailyKanjiTestLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Learning
  alias Medoru.Repo
  alias Medoru.Learning.UserDailyChallenge

  describe "mount" do
    test "shows challenge when user has enough learned kanji with stroke data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      Enum.each(1..15, fn i ->
        kanji =
          kanji_fixture(%{
            character: <<0x3400 + i::utf8>>,
            stroke_data: %{"strokes" => ["M0,0 L10,10"]}
          })

        Learning.track_kanji_learned(user.id, kanji.id)
      end)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/kanji")

      assert html =~ "Daily Kanji Challenge"
    end

    test "shows error when user has fewer than 15 learned kanji", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      Enum.each(1..5, fn i ->
        kanji =
          kanji_fixture(%{
            character: <<0x3400 + i::utf8>>,
            stroke_data: %{"strokes" => ["M0,0 L10,10"]}
          })

        Learning.track_kanji_learned(user.id, kanji.id)
      end)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/kanji")

      assert html =~ "Not enough learned kanji"
    end

    test "shows already completed when challenge was done today", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      %UserDailyChallenge{}
      |> UserDailyChallenge.changeset(%{
        user_id: user.id,
        challenge_type: "daily_kanji",
        date: Date.utc_today(),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        xp_awarded: 100
      })
      |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/kanji")

      assert html =~ "Already Completed"
    end
  end

  defp extract_current_kanji_id(html) do
    # Parse the kanji writing component ID to get the current kanji ID
    case Regex.run(~r/id=\"daily-kanji-writing-([a-f0-9-]+)\"/, html) do
      [_, kanji_id] -> kanji_id
      _ -> nil
    end
  end

  describe "challenge flow" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      kanji_list =
        Enum.map(1..15, fn i ->
          kanji =
            kanji_fixture(%{
              character: <<0x3400 + i::utf8>>,
              stroke_data: %{"strokes" => ["M0,0 L10,10"]}
            })

          Learning.track_kanji_learned(user.id, kanji.id)
          kanji
        end)

      %{conn: conn, user: user, kanji_list: kanji_list}
    end

    test "completing all kanji shows results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/daily-challenges/kanji")

      # Complete all 15 kanji by sending hooks directly to the view
      Enum.each(1..15, fn _ ->
        render_hook(view, "kanji_complete", %{"wrong_strokes" => 0})
      end)

      html = render(view)
      assert html =~ "Challenge Complete"
    end

    test "known_score increases on correct kanji", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/daily-challenges/kanji")

      # Get the current kanji ID from the HTML
      current_kanji_id = extract_current_kanji_id(html)
      progress_before = Learning.get_kanji_progress(user.id, current_kanji_id)
      assert progress_before.known_score == 1

      render_hook(view, "kanji_complete", %{"wrong_strokes" => 0})

      progress_after = Learning.get_kanji_progress(user.id, current_kanji_id)
      assert progress_after.known_score == 2
    end

    test "shows readings with the lowest admin-defined position first", %{
      conn: conn,
      kanji_list: kanji_list
    } do
      Enum.each(kanji_list, fn kanji ->
        kanji_reading_fixture(kanji.id, %{
          reading_type: :on,
          reading: "カター",
          romaji: "kataa",
          position: 5
        })

        kanji_reading_fixture(kanji.id, %{
          reading_type: :on,
          reading: "アター",
          romaji: "ataa",
          position: 1
        })

        kanji_reading_fixture(kanji.id, %{
          reading_type: :kun,
          reading: "あと",
          romaji: "ato",
          position: 6
        })

        kanji_reading_fixture(kanji.id, %{
          reading_type: :kun,
          reading: "さき",
          romaji: "saki",
          position: 2
        })
      end)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/kanji")

      assert html =~ "アター"
      assert html =~ "さき"
      refute html =~ "カター"
      refute html =~ "あと"
    end

    test "shows a word hint for the current kanji", %{conn: conn, kanji_list: kanji_list} do
      Enum.each(kanji_list, fn kanji ->
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
      end)

      {:ok, _view, html} = live(conn, ~p"/daily-challenges/kanji")

      assert html =~ "hint word meaning"
      assert html =~ "てすと"
    end

    test "known_score decreases but not below 1 on incorrect kanji", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/daily-challenges/kanji")

      current_kanji_id = extract_current_kanji_id(html)
      progress_before = Learning.get_kanji_progress(user.id, current_kanji_id)
      initial_score = progress_before.known_score

      render_hook(view, "submit_writing", %{"completed" => "false", "wrong_strokes" => 5})

      progress_after = Learning.get_kanji_progress(user.id, current_kanji_id)
      # Should decrease by 1 but not below 1
      expected_score = max(initial_score - 1, 1)
      assert progress_after.known_score == expected_score
    end
  end
end
