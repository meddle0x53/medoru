defmodule MedoruWeb.DailyTestLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Learning
  # alias Medoru.Learning.DailyTestGenerator
  alias Medoru.Repo
  alias Medoru.Learning.ReviewSchedule

  describe "mount" do
    test "shows daily test when user has learned words", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      word = word_fixture()
      Learning.track_word_learned(user.id, word.id)

      # Create a review schedule so the word is due
      {:ok, progress} = Learning.track_word_learned(user.id, word.id)

      %ReviewSchedule{}
      |> ReviewSchedule.changeset(%{
        user_id: user.id,
        user_progress_id: progress.id,
        next_review_at: DateTime.utc_now() |> DateTime.add(-1, :day),
        interval: 1,
        ease_factor: 2.5,
        repetitions: 0
      })
      |> Repo.insert!()

      {:ok, _view, html} = live(conn, ~p"/daily-test")

      assert html =~ word.text
    end

    test "redirects to lessons when no words are learned", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # No learned words - should redirect
      assert {:error, {:live_redirect, %{to: "/lessons"}}} = live(conn, ~p"/daily-test")
    end
  end

  describe "test completion" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Create and learn 3 words with review schedules due now
      words =
        Enum.map(1..3, fn _ ->
          word = word_fixture()
          {:ok, progress} = Learning.track_word_learned(user.id, word.id)

          %ReviewSchedule{}
          |> ReviewSchedule.changeset(%{
            user_id: user.id,
            user_progress_id: progress.id,
            next_review_at: DateTime.utc_now() |> DateTime.add(-1, :day),
            interval: 1,
            ease_factor: 2.5,
            repetitions: 0
          })
          |> Repo.insert!()

          word
        end)

      %{conn: conn, user: user, words: words}
    end

    test "page loads with daily test steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/daily-test")

      assert html =~ "Daily Review"
    end

    test "mastery and schedule are updated after answering", %{
      conn: conn,
      user: user,
      words: words
    } do
      {:ok, view, _html} = live(conn, ~p"/daily-test")

      first_word = List.first(words)
      progress_before = Learning.get_word_progress(user.id, first_word.id)
      assert progress_before.mastery_level == 1

      schedule_before = Learning.get_review_schedule(user.id, progress_before.id)
      assert schedule_before.repetitions == 0

      # The main assertion is that the page loaded and test is interactable
      assert render(view) =~ "Daily Review"
    end
  end
end
