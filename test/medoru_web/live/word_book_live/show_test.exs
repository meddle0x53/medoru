defmodule MedoruWeb.WordBookLive.ShowTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordBooks
  alias Medoru.WhiteBoard

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "cover" do
    test "redirects non-owners back to the index", %{conn: conn} do
      other = user_fixture()
      word_book = word_book_fixture(%{user_id: other.id})

      assert {:error, {:live_redirect, %{to: "/words/books"}}} =
               live(conn, ~p"/words/books/#{word_book.id}")
    end

    test "shows an empty-book notice with a link to edit-words instead of Open",
         %{conn: conn, user: user} do
      word_book = word_book_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}")

      assert html =~ "This book has no words yet."
      assert html =~ "/words/books/#{word_book.id}/edit-words"
      refute html =~ ~s(phx-click="open_book")
    end

    test "renders the generated default cover when no cover_image is set",
         %{conn: conn, user: user} do
      word = word_fixture(%{text: "読む", reading: "よむ", meaning: "to read"})
      word_book = word_book_with_words_fixture(%{user_id: user.id, title: "My Book"}, [word])

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}")

      assert html =~ "My Book"
      assert html =~ "読む"
      assert html =~ "1 word"
      assert html =~ ~s(phx-click="open_book")
      refute html =~ "/images/word_book/covers/"
    end

    test "renders the preset cover image when cover_image is set",
         %{conn: conn, user: user} do
      word = word_fixture()

      word_book =
        word_book_with_words_fixture(%{user_id: user.id, cover_image: "sakura"}, [word])

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}")

      assert html =~ "/images/word_book/covers/sakura.svg"
    end

    test "shows design and edit-words links for the owner", %{conn: conn, user: user} do
      word_book = word_book_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}")

      assert html =~ "/words/books/#{word_book.id}/design"
      assert html =~ "/words/books/#{word_book.id}/edit-words"
    end
  end

  describe "open book" do
    test "shows the cards of the first page after opening", %{conn: conn, user: user} do
      word = word_fixture(%{text: "読む", reading: "よむ", meaning: "to read"})
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")

      html = view |> element(~s([phx-click="open_book"])) |> render_click()

      assert html =~ ~s(id="card-#{word.id}-front")
      assert html =~ "読む"
      assert html =~ "Page 1 of 1"
    end

    test "renders a flip-aware download button for each card", %{conn: conn, user: user} do
      word = word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")

      html = view |> element(~s([phx-click="open_book"])) |> render_click()

      assert html =~ ~s(data-share-front="card-#{word.id}-front")
      assert html =~ ~s(data-share-back="card-#{word.id}-back")
      assert html =~ ~s(data-filename="medoru-card-#{word.id}")
      # Branding is rendered on the card faces so it lands in downloaded images
      assert html =~ "medoru.net"
    end

    test "cards-per-page selector changes the grid and persists to the DB",
         %{conn: conn, user: user} do
      words = for _ <- 1..9, do: word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, words)

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")

      view |> element(~s([phx-click="open_book"])) |> render_click()

      # Default is 4 per page (2x2)
      assert render(view) =~ "grid-cols-1 sm:grid-cols-2"
      assert WordBooks.get_word_book!(word_book.id).cards_per_page == 4

      view
      |> element(~s(button[phx-click="set_cards_per_page"][phx-value-count="2"]))
      |> render_click()

      assert render(view) =~ "max-w-2xl mx-auto"
      assert WordBooks.get_word_book!(word_book.id).cards_per_page == 2

      view
      |> element(~s(button[phx-click="set_cards_per_page"][phx-value-count="6"]))
      |> render_click()

      html = render(view)
      assert html =~ "lg:grid-cols-3"
      assert html =~ "Page 1 of 2"
      assert WordBooks.get_word_book!(word_book.id).cards_per_page == 6
    end

    test "paginates with prev/next across pages", %{conn: conn, user: user} do
      first_word = word_fixture(%{text: "一ページ目", meaning: "first page"})
      middle_words = for _ <- 1..8, do: word_fixture()
      last_word = word_fixture(%{text: "最後の頁", meaning: "last page"})

      word_book =
        word_book_with_words_fixture(
          %{user_id: user.id, cards_per_page: 6},
          [first_word | middle_words] ++ [last_word]
        )

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")

      html = view |> element(~s([phx-click="open_book"])) |> render_click()

      assert html =~ "Page 1 of 2"
      assert html =~ "一ページ目"
      refute html =~ "最後の頁"

      html = view |> element(~s(a[href="/words/books/#{word_book.id}?page=2"])) |> render_click()

      assert html =~ "Page 2 of 2"
      assert html =~ "最後の頁"
      refute html =~ "一ページ目"

      html = view |> element(~s(a[href="/words/books/#{word_book.id}?page=1"])) |> render_click()

      assert html =~ "Page 1 of 2"
      assert html =~ "一ページ目"
    end

    test "close book returns to the cover", %{conn: conn, user: user} do
      word = word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")

      view |> element(~s([phx-click="open_book"])) |> render_click()

      html = view |> element(~s(button[phx-click="close_book"])) |> render_click()

      assert html =~ ~s(phx-click="open_book")
      assert html =~ word_book.title
    end

    test "posting a card creates a white board post with a snapshot", %{
      conn: conn,
      user: user
    } do
      word = word_fixture(%{text: "読む", meaning: "to read"})

      word_book =
        word_book_with_words_fixture(%{user_id: user.id, custom_text: "Word Of The Day"}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}")
      view |> element(~s([phx-click="open_book"])) |> render_click()

      html = view |> element(~s(button[phx-click="post_card_to_board"])) |> render_click()

      assert html =~ "Card posted to your White Board."

      [post] = WhiteBoard.list_posts(user.id, user.id)
      assert post.post_type == "word_card"
      assert post.card_data["word"]["text"] == "読む"
      assert post.card_data["custom_text"] == "Word Of The Day"
      assert post.card_data["book_title"] == word_book.title
    end
  end
end
