defmodule MedoruWeb.WordLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}
  alias Medoru.Learning

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

    test "sets og:image meta tag when word has an image", %{conn: conn} do
      word =
        word_fixture(%{text: "画像語", reading: "がぞうご", image_path: "/uploads/word_images/test.jpg"})

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~
               ~r/<meta[^>]*property="og:image"[^>]*content="[^"]*\/uploads\/word_images\/test\.jpg"[^>]*>/
    end

    test "does not set og:image meta tag when word has no image", %{conn: conn} do
      word = word_fixture(%{text: "無画像語", reading: "むがぞうご", image_path: nil})

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      refute html =~ ~r/<meta[^>]*property="og:image"[^>]*>/
      assert html =~ ~r/<meta[^>]*property="og:title"[^>]*>/
      assert html =~ ~r/<meta[^>]*property="og:description"[^>]*>/
    end

    test "displays approved linked relations", %{conn: conn} do
      word = word_fixture(%{text: "大きい", reading: "おおきい", word_type: :adjective})
      related = word_fixture(%{text: "大きな", reading: "おおきな"})

      {:ok, _} =
        Medoru.Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :approved
        })

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "Synonyms"
      assert html =~ related.text
    end

    test "displays approved text-only expressions", %{conn: conn} do
      word = word_fixture(%{text: "日本", reading: "にほん", word_type: :noun})

      {:ok, _} =
        Medoru.Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :expression,
          expression_text: "日本に行く",
          status: :approved
        })

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "Common Expressions"
      assert html =~ "日本に行く"
    end

    test "does not display pending relations", %{conn: conn} do
      word = word_fixture(%{text: "日本", reading: "にほん", word_type: :noun})
      related = word_fixture(%{text: "国", reading: "くに"})

      {:ok, _} =
        Medoru.Content.create_word_relation(%{
          word_id: word.id,
          relation_type: :synonym,
          related_word_id: related.id,
          status: :pending
        })

      {:ok, _view, html} = live(conn, ~p"/words/#{word.id}")

      refute html =~ "Synonyms"
      refute html =~ related.text
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

  describe "English-learning mode" do
    setup [:create_word]

    test "index shows Learned badge from user_english_progress", %{conn: conn, word: word} do
      user = user_fixture(%{learning_language: "english"})
      {:ok, _} = Learning.track_english_word_learned(user.id, word.id)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/words")

      assert html =~ "Learned"
      assert html =~ word.text
      assert html =~ word.meaning
    end

    test "show page toggles user_english_progress", %{conn: conn, word: word} do
      user = user_fixture(%{learning_language: "english"})
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/words/#{word.id}")

      assert html =~ "Mark as Learned"
      refute html =~ "Learned (click to unlearn)"

      view
      |> element("button", "Mark as Learned")
      |> render_click()

      assert render(view) =~ "Learned (click to unlearn)"
      assert Learning.english_word_learned?(user.id, word.id)

      view
      |> element("button", "Learned (click to unlearn)")
      |> render_click()

      assert render(view) =~ "Mark as Learned"
      refute Learning.english_word_learned?(user.id, word.id)
    end
  end
end
