defmodule MedoruWeb.NotificationsLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

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
end
