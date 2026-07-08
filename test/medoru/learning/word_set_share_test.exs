defmodule Medoru.Learning.WordSetShareTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordSets
  alias Medoru.Notifications
  alias Medoru.Social

  describe "share_word_set/3" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()
      stranger = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_set = word_set_fixture(%{user_id: sender.id})
      word = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word.id)

      %{sender: sender, recipient: recipient, stranger: stranger, word_set: word_set, word: word}
    end

    test "creates a pending share and notification", %{
      sender: sender,
      recipient: recipient,
      word_set: word_set
    } do
      assert {:ok, share} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)
      assert share.status == "pending"
      assert share.word_set_id == word_set.id
      assert share.sender_id == sender.id
      assert share.recipient_id == recipient.id

      notification = Notifications.list_notifications_by_type(recipient.id, "word_set_share")
      assert length(notification) == 1
      assert notification |> hd() |> Map.get(:data) |> Map.get("share_id") == share.id
    end

    test "rejects when sender does not own the word set", %{
      recipient: recipient,
      stranger: stranger,
      word_set: word_set
    } do
      assert {:error, :not_owner} =
               WordSets.share_word_set(stranger.id, word_set.id, recipient.id)
    end

    test "rejects when users are not mutual followers", %{
      sender: sender,
      stranger: stranger,
      word_set: word_set
    } do
      assert {:error, :not_mutual} =
               WordSets.share_word_set(sender.id, word_set.id, stranger.id)
    end

    test "rejects duplicate pending share", %{
      sender: sender,
      recipient: recipient,
      word_set: word_set
    } do
      assert {:ok, _} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)

      assert {:error, :already_shared} =
               WordSets.share_word_set(sender.id, word_set.id, recipient.id)
    end
  end

  describe "accept_word_set_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_set =
        word_set_fixture(%{user_id: sender.id, name: "Shared Set", description: "A shared set"})

      word1 = word_fixture()
      word2 = word_fixture()
      {:ok, _} = WordSets.add_word_to_set(word_set, word1.id)
      {:ok, _} = WordSets.add_word_to_set(word_set, word2.id)

      {:ok, share} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)

      %{
        sender: sender,
        recipient: recipient,
        word_set: word_set,
        share: share,
        words: [word1, word2]
      }
    end

    test "copies the word set to the recipient", %{
      recipient: recipient,
      word_set: word_set,
      share: share
    } do
      assert {:ok, copied_set} = WordSets.accept_word_set_share(share.id, recipient.id)
      assert copied_set.user_id == recipient.id
      assert copied_set.name == word_set.name
      assert copied_set.description == word_set.description
      assert copied_set.word_count == 2
      assert is_nil(copied_set.practice_test_id)

      share = WordSets.get_word_set_share(share.id)
      assert share.status == "accepted"
    end

    test "rejects non-recipient acceptance", %{sender: sender, share: share} do
      assert {:error, :not_recipient} = WordSets.accept_word_set_share(share.id, sender.id)
    end
  end

  describe "delete_word_set_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_set = word_set_fixture(%{user_id: sender.id})
      {:ok, share} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)

      %{sender: sender, recipient: recipient, share: share}
    end

    test "deletes share", %{recipient: recipient, share: share} do
      assert {:ok, deleted} = WordSets.delete_word_set_share(share.id, recipient.id)
      assert deleted.id == share.id
      assert is_nil(WordSets.get_word_set_share(share.id))
    end

    test "rejects non-recipient deletion", %{sender: sender, share: share} do
      assert {:error, :not_recipient} = WordSets.delete_word_set_share(share.id, sender.id)
    end
  end

  describe "cancel_word_set_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_set = word_set_fixture(%{user_id: sender.id})
      {:ok, share} = WordSets.share_word_set(sender.id, word_set.id, recipient.id)

      %{sender: sender, recipient: recipient, share: share}
    end

    test "marks share as cancelled", %{recipient: recipient, share: share} do
      assert {:ok, cancelled} = WordSets.cancel_word_set_share(share.id, recipient.id)
      assert cancelled.status == "cancelled"
    end
  end
end
