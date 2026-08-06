defmodule MedoruWeb.WordBookLive.DesignTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordBooks

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "Design word book" do
    test "redirects non-owners back to the index", %{conn: conn} do
      other = user_fixture()
      word_book = word_book_fixture(%{user_id: other.id})

      assert {:error, {:live_redirect, %{to: "/words/books"}}} =
               live(conn, ~p"/words/books/#{word_book.id}/design")
    end

    test "shows an empty-book notice with a link to edit-words", %{conn: conn, user: user} do
      word_book = word_book_fixture(%{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/words/books/#{word_book.id}/design")

      assert html =~ "This book has no words yet."
      assert html =~ "/words/books/#{word_book.id}/edit-words"
    end

    test "previews the first word and updates on control changes", %{conn: conn, user: user} do
      word = word_fixture(%{text: "読む", reading: "よむ", meaning: "to read"})
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, html} = live(conn, ~p"/words/books/#{word_book.id}/design")

      assert html =~ "読む"
      assert html =~ ~s(id="word-book-design-preview-front")

      # Toggle the reading checkbox on the front side
      view
      |> element(~s(input[phx-click="toggle_option"][phx-value-key="show_reading"]))
      |> render_click()

      assert render(view) =~ "よむ"

      # Switch to the back side and enable a meaning locale
      view
      |> element("button[phx-click='switch_side'][phx-value-side='back']")
      |> render_click()

      view
      |> element(
        ~s(input[phx-click="toggle_locale"][phx-value-group="meanings"][phx-value-locale="en"])
      )
      |> render_click()

      assert render(view) =~ "to read"
    end

    test "saves the design", %{conn: conn, user: user} do
      word = word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}/design")

      view
      |> element("button[phx-click='select_shape'][phx-value-shape='square']")
      |> render_click()

      view
      |> element("button[phx-click='select_background'][phx-value-background='sakura']")
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_option"][phx-value-key="show_reading"]))
      |> render_click()

      view
      |> element("button[phx-click='save']")
      |> render_click()

      word_book = WordBooks.get_word_book!(word_book.id)

      assert word_book.card_shape == "square"
      assert word_book.front_background == "sakura"
      assert word_book.front_config["show_reading"] == true
      assert word_book.front_config["example_count"] == "all"
      assert word_book.back_config["show_reading"] == false
    end

    test "example count change sticks through other events and save", %{
      conn: conn,
      user: user
    } do
      # Regression: the example-count control used to be a <select> whose
      # phx-change payload didn't match the handler (crashing the view) and
      # whose displayed value could be reverted by unrelated patches. It is
      # now a segmented button group.
      word = word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}/design")

      view
      |> element(~s(button[phx-click="set_example_count"][phx-value-count="1"]))
      |> render_click()

      assert has_element?(
               view,
               ~s(button[phx-click="set_example_count"][phx-value-count="1"].btn-primary)
             )

      # Other events must not revert the selection
      view
      |> element(~s(input[phx-click="toggle_option"][phx-value-key="show_reading"]))
      |> render_click()

      assert has_element?(
               view,
               ~s(button[phx-click="set_example_count"][phx-value-count="1"].btn-primary)
             )

      view |> element("button[phx-click='save']") |> render_click()

      assert WordBooks.get_word_book!(word_book.id).front_config["example_count"] == 1
    end

    test "sets custom text, previews it, and saves it", %{conn: conn, user: user} do
      word = word_fixture()
      word_book = word_book_with_words_fixture(%{user_id: user.id}, [word])

      {:ok, view, _html} = live(conn, ~p"/words/books/#{word_book.id}/design")

      html =
        view
        |> element(~s(input[name="custom_text"]))
        |> render_change(%{"custom_text" => "Word Of The Day"})

      # Live preview shows the text
      assert html =~ "Word Of The Day"

      view |> element("button[phx-click='save']") |> render_click()

      assert WordBooks.get_word_book!(word_book.id).custom_text == "Word Of The Day"
    end
  end
end
