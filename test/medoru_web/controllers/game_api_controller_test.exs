defmodule MedoruWeb.GameApiControllerTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Repo
  alias Medoru.Learning
  alias Medoru.Learning.UserDailyChallenge

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "POST /api/game/run-result" do
    test "daily challenge run records ouroboros_run completion and awards essence XP",
         %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/game/run-result", %{
          "daily_challenge_mode" => true,
          "earned_ouro_essence" => 5,
          "winner" => "player",
          "learned_word_ids" => [],
          "focus_kanji" => nil
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      challenge =
        Repo.get_by(UserDailyChallenge,
          user_id: user.id,
          challenge_type: "ouroboros_run",
          date: Date.utc_today()
        )

      assert challenge
      assert challenge.xp_awarded == 500
      assert challenge.score == 5
      assert challenge.metadata["earned_ouro_essence"] == 5
      assert challenge.metadata["victory"] == true
    end

    test "regular run does not record a daily challenge", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/game/run-result", %{
          "daily_challenge_mode" => false,
          "earned_ouro_essence" => 10,
          "winner" => "player",
          "learned_word_ids" => [],
          "focus_kanji" => nil
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      refute Repo.get_by(UserDailyChallenge,
               user_id: user.id,
               challenge_type: "ouroboros_run",
               date: Date.utc_today()
             )
    end

    test "failed daily challenge run still records ouroboros_run completion with 0 XP",
         %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/game/run-result", %{
          "daily_challenge_mode" => true,
          "earned_ouro_essence" => 0,
          "winner" => "enemy",
          "learned_word_ids" => [],
          "focus_kanji" => nil
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      challenge =
        Repo.get_by(UserDailyChallenge,
          user_id: user.id,
          challenge_type: "ouroboros_run",
          date: Date.utc_today()
        )

      assert challenge
      assert challenge.xp_awarded == 0
      assert challenge.score == 0
      assert challenge.metadata["victory"] == false
    end

    test "run result marks learned words and focus kanji as learned", %{conn: conn, user: user} do
      word = word_fixture()
      kanji = kanji_fixture(%{character: "力"})

      conn =
        post(conn, ~p"/api/game/run-result", %{
          "daily_challenge_mode" => false,
          "earned_ouro_essence" => 0,
          "winner" => "enemy",
          "learned_word_ids" => [word.id],
          "focus_kanji" => kanji.character
        })

      assert json_response(conn, 200) == %{"status" => "ok"}

      assert Learning.word_learned_for_user?(user, word.id)
      assert Learning.kanji_learned?(user.id, kanji.id)
    end
  end
end
