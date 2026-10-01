defmodule MedoruWeb.NotificationsLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordBooks
  alias Medoru.Learning.WordSets
  alias Medoru.Notifications
  alias Medoru.Social

  describe "word set share notifications" do
    setup %{conn: conn} do
      sender = user_fixture_with_profile(%{name: "Sender"})
      recipient = user_fixture_with_profile(%{name: "Recipient"})

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_set = word_set_fixture(%{user_id: sender.id, name: "Shared Words"})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      {:ok, share} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)
      [notification] = Notifications.list_notifications_by_type(recipient.id, "word_set_share")

      conn = log_in_user(conn, recipient)

      %{
        conn: conn,
        sender: sender,
        recipient: recipient,
        word_set: word_set,
        share: share,
        notification: notification
      }
    end

    test "renders word set share notification with accept and cancel buttons", %{
      conn: conn,
      notification: notification
    } do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "wants to share a word set"
      assert html =~ "Shared Words"
      assert html =~ "phx-click=\"accept_word_set_share\""
      assert html =~ "phx-click=\"cancel_word_set_share\""
      assert html =~ "phx-value-id=\"#{notification.id}\""
    end

    test "accepting a share copies the word set to recipient", %{
      conn: conn,
      recipient: recipient,
      notification: notification,
      word_set: word_set
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("accept_word_set_share", %{"id" => notification.id})

      assert_redirect(
        view,
        ~p"/words/sets/#{WordSets.list_user_word_sets(recipient.id).word_sets |> hd() |> Map.get(:id)}"
      )

      copied_sets = WordSets.list_user_word_sets(recipient.id)
      assert copied_sets.total_count == 1
      copied = hd(copied_sets.word_sets)
      assert copied.name == word_set.name
      assert copied.word_count == 1

      share = WordSets.get_word_set_share(notification.data["share_id"])
      assert share.status == "accepted"
    end

    test "canceling a share deletes the share and notification", %{
      conn: conn,
      recipient: recipient,
      notification: notification
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("cancel_word_set_share", %{"id" => notification.id})

      assert is_nil(WordSets.get_word_set_share(notification.data["share_id"]))
      assert Notifications.list_notifications_by_type(recipient.id, "word_set_share") == []
    end

    test "deleting the notification also deletes the share", %{
      conn: conn,
      recipient: recipient,
      notification: notification
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("delete", %{"id" => notification.id})

      assert is_nil(WordSets.get_word_set_share(notification.data["share_id"]))
      assert Notifications.list_notifications_by_type(recipient.id, "word_set_share") == []
    end
  end

  describe "word book share notifications" do
    setup %{conn: conn} do
      sender = user_fixture_with_profile(%{name: "Book Sender"})
      recipient = user_fixture_with_profile(%{name: "Book Recipient"})

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word = word_fixture()

      word_book =
        word_book_fixture(%{
          user_id: sender.id,
          title: "Shared Book",
          theme: "dark",
          card_shape: "square",
          cards_per_page: 2,
          custom_text: "Daily review",
          front_config: %{"show_word" => true, "meanings" => ["en"]},
          back_config: %{"show_reading" => true, "example_count" => 2}
        })

      word_book =
        Enum.reduce([word], word_book, fn w, book ->
          {:ok, book} = WordBooks.add_word_to_book(book, w.id)
          book
        end)

      {:ok, share} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)
      [notification] = Notifications.list_notifications_by_type(recipient.id, "word_book_share")

      conn = log_in_user(conn, recipient)

      %{
        conn: conn,
        sender: sender,
        recipient: recipient,
        word_book: word_book,
        share: share,
        notification: notification
      }
    end

    test "renders word book share notification with accept and cancel buttons", %{
      conn: conn,
      notification: notification
    } do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "wants to share a word book"
      assert html =~ "Shared Book"
      assert html =~ "phx-click=\"accept_word_book_share\""
      assert html =~ "phx-click=\"cancel_word_book_share\""
      assert html =~ "phx-value-id=\"#{notification.id}\""
    end

    test "accepting a share copies the word book to recipient", %{
      conn: conn,
      recipient: recipient,
      notification: notification
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("accept_word_book_share", %{"id" => notification.id})

      copied_books = WordBooks.list_user_word_books(recipient.id).word_books
      assert length(copied_books) == 1
      copied = hd(copied_books)

      assert_redirect(view, ~p"/words/books/#{copied.id}")

      assert copied.title == "Shared Book"
      assert copied.theme == "dark"
      assert copied.card_shape == "square"
      assert copied.cards_per_page == 2
      assert copied.custom_text == "Daily review"
      assert copied.front_config == %{"show_word" => true, "meanings" => ["en"]}
      assert copied.back_config == %{"show_reading" => true, "example_count" => 2}
      assert copied.word_count == 1

      share = WordBooks.get_word_book_share(notification.data["share_id"])
      assert share.status == "accepted"
    end

    test "canceling a share deletes the share and notification", %{
      conn: conn,
      recipient: recipient,
      notification: notification
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("cancel_word_book_share", %{"id" => notification.id})

      assert is_nil(WordBooks.get_word_book_share(notification.data["share_id"]))
      assert Notifications.list_notifications_by_type(recipient.id, "word_book_share") == []
    end

    test "deleting the notification also deletes the share", %{
      conn: conn,
      recipient: recipient,
      notification: notification
    } do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> render_click("delete", %{"id" => notification.id})

      assert is_nil(WordBooks.get_word_book_share(notification.data["share_id"]))
      assert Notifications.list_notifications_by_type(recipient.id, "word_book_share") == []
    end
  end
end
