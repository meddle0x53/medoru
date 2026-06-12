defmodule MedoruWeb.WordLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  describe "Index" do
    setup [:create_word, :create_user]

    test "lists all words", %{conn: conn, word: word} do
      {:ok, _view, html} = live(conn, ~p"/words")

      assert html =~ "Vocabulary Browser"
      assert html =~ word.text
      assert html =~ word.meaning
    end

    test "filters words by difficulty", %{conn: conn} do
      _n5_word = word_fixture(%{difficulty: 5, text: "語一", reading: "ごいち"})
      _n4_word = word_fixture(%{difficulty: 4, text: "語二", reading: "ごに"})

      # Navigate to N5 filter - should show N5
      {:ok, _view, html} = live(conn, ~p"/words?difficulty=5")
      assert html =~ "N5"
      assert html =~ "words"

      # Navigate to N4 filter - should show N4
      {:ok, _view, html} = live(conn, ~p"/words?difficulty=4")
      assert html =~ "N4"
      assert html =~ "words"
    end

    test "displays word count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/words")

      assert html =~ "words"
    end

    test "shows empty state when no words", %{conn: conn} do
      # Test with difficulty that has no words (N1)
      {:ok, view, _html} = live(conn, ~p"/words?difficulty=1")

      assert render(view) =~ "No words found"
    end

    test "authenticated user can access word browser", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/words")

      assert html =~ "Vocabulary Browser"
    end
  end

  describe "mature content filtering" do
    test "hides mature words from anonymous users on index", %{conn: conn} do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})

      {:ok, _view, html} = live(conn, ~p"/words")

      refute html =~ word.text
    end

    test "hides mature words from restricted users on index", %{conn: conn} do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/words")

      refute html =~ word.text
    end

    test "shows mature words to adult users with safety disabled on index", %{
      conn: conn
    } do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/words")

      assert html =~ word.text
    end

    test "redirects anonymous users away from mature word show page", %{conn: conn} do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})

      assert {:error, {:live_redirect, %{to: "/words", flash: %{"error" => "Word not found."}}}} =
               live(conn, ~p"/words/#{word.id}")
    end

    test "redirects restricted users away from mature word show page", %{conn: conn} do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/words", flash: %{"error" => "Word not found."}}}} =
               live(conn, ~p"/words/#{word.id}")
    end

    test "allows adult users with safety disabled to view mature word show page", %{
      conn: conn
    } do
      word = word_fixture(%{mature: true, text: "成人", reading: "せいじん"})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ word.text
    end
  end

  describe "Show" do
    setup [:create_word_with_kanji, :create_user]

    test "displays word details", %{conn: conn, word: word} do
      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ word.text
      assert html =~ word.reading
      assert html =~ word.meaning
    end

    test "displays kanji breakdown", %{conn: conn, word: word} do
      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "Kanji Breakdown"

      # Check that each kanji is displayed
      for wk <- word.word_kanjis do
        assert html =~ wk.kanji.character
      end
    end

    test "has back link to word list", %{conn: conn, word: word} do
      {:ok, view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "Back to N#{word.difficulty} Words"
      assert has_element?(view, "a[href='/words?difficulty=#{word.difficulty}']")
    end

    test "displays JLPT level badge", %{conn: conn, word: word} do
      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "JLPT N#{word.difficulty}"
    end

    test "displays common word badge for frequent words", %{conn: conn} do
      common_word = word_fixture(%{usage_frequency: 50, text: "常用語", reading: "じょうようご"})

      {:ok, _view, html} = live(conn, ~p"/words/#{common_word.id}")

      assert html =~ "Common word"
    end

    test "404 for non-existent word", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/words/#{Ecto.UUID.generate()}")
      end
    end
  end

  defp create_word(_) do
    word = word_fixture()
    %{word: word}
  end

  defp create_word_with_kanji(_) do
    word = word_with_kanji_fixture()
    %{word: word}
  end

  defp create_user(_) do
    user = user_fixture()
    %{user: user}
  end
end
