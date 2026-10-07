defmodule MedoruWeb.WordBookLive.PresentTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  describe "public presentation" do
    test "renders the book for anyone without login", %{conn: conn} do
      user = user_fixture_with_profile(%{name: "Present Author"})
      word = word_fixture(%{text: "読む", reading: "よむ", meaning: "to read"})

      word_book =
        word_book_with_words_fixture(%{user_id: user.id, title: "Present Book"}, [word])

      {:ok, _view, html} = live(conn, ~p"/word-books/#{word_book.id}")

      assert html =~ "Present Book"
      assert html =~ "Present Author"
      assert html =~ "読む"
      assert html =~ ~s(phx-hook="WordBookPresent")
      assert html =~ "present-card-#{word.id}-front"
      assert html =~ "present-card-#{word.id}-back"
      assert html =~ ~s(id="word-book-flipbook")
      assert html =~ ~s(id="wb-prev-btn")
      assert html =~ ~s(id="wb-next-btn")
      assert html =~ ~s(aria-label="Previous")
      assert html =~ ~s(aria-label="Next")
    end

    test "renders in the locale from the URL param", %{conn: conn} do
      user = user_fixture()
      word_book = word_book_fixture(%{user_id: user.id, title: "Locale Book"})

      {:ok, _view, html} = live(conn, ~p"/word-books/#{word_book.id}?locale=bg")

      assert html =~ "Копирай връзката"
      assert html =~ "Locale Book"
    end

    test "owner sees a back link to the normal book view, others do not", %{
      conn: conn
    } do
      owner = user_fixture()
      other = user_fixture()

      word_book =
        word_book_with_words_fixture(%{user_id: owner.id, title: "Owner Book"}, [])

      # Anonymous
      {:ok, _view, html} = live(conn, ~p"/word-books/#{word_book.id}")
      refute html =~ ~s(href="/words/books/#{word_book.id}")

      # Different logged-in user
      conn2 = log_in_user(build_conn(), other)
      {:ok, _view, html} = live(conn2, ~p"/word-books/#{word_book.id}")
      refute html =~ ~s(href="/words/books/#{word_book.id}")

      # Owner
      conn3 = log_in_user(build_conn(), owner)
      {:ok, _view, html} = live(conn3, ~p"/word-books/#{word_book.id}")
      assert html =~ ~s(href="/words/books/#{word_book.id}")
    end

    test "renders a cover page with the book title", %{conn: conn} do
      user = user_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id, title: "Cover Title"}, [])

      {:ok, _view, html} = live(conn, ~p"/word-books/#{word_book.id}")

      assert html =~ ~s(class="wb-page wb-cover-page")
      assert html =~ "Cover Title"
    end

    test "renders both card faces as separate print blocks", %{conn: conn} do
      user = user_fixture()
      word = word_fixture(%{text: "読む", meaning: "to read"})
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, _view, html} = live(conn, ~p"/word-books/#{word_book.id}")

      assert html =~ ~s(class="wb-print")
      assert html =~ "print-card-#{word.id}-front"
      assert html =~ "print-card-#{word.id}-back"
    end

    test "unknown uuid redirects to home with a flash message", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/word-books/#{Ecto.UUID.generate()}")
    end
  end

  describe "owner show page" do
    test "links to the public presentation and offers copy-link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      word_book = word_book_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}")

      assert html =~ ~s(href="/word-books/#{word_book.id}")
      assert html =~ ~s(id="present-copy-link-#{word_book.id}")
      assert html =~ ~s(phx-hook="CopyToClipboard")
      assert html =~ "Present"
      assert html =~ "Copy link"
    end
  end
end
