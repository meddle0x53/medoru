defmodule Medoru.Learning.WordBookShareTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordBooks
  alias Medoru.Notifications
  alias Medoru.Social

  describe "share_word_book/3" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()
      stranger = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_book = word_book_fixture(%{user_id: sender.id})
      word = word_fixture()
      {:ok, word_book} = WordBooks.add_word_to_book(word_book, word.id)

      %{
        sender: sender,
        recipient: recipient,
        stranger: stranger,
        word_book: word_book,
        word: word
      }
    end

    test "creates a pending share and notification", %{
      sender: sender,
      recipient: recipient,
      word_book: word_book
    } do
      assert {:ok, share} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)
      assert share.status == "pending"
      assert share.word_book_id == word_book.id
      assert share.sender_id == sender.id
      assert share.recipient_id == recipient.id

      notification = Notifications.list_notifications_by_type(recipient.id, "word_book_share")
      assert length(notification) == 1
      assert notification |> hd() |> Map.get(:data) |> Map.get("share_id") == share.id

      assert notification |> hd() |> Map.get(:data) |> Map.get("word_book_title") ==
               word_book.title
    end

    test "rejects when sender does not own the word book", %{
      recipient: recipient,
      stranger: stranger,
      word_book: word_book
    } do
      assert {:error, :not_owner} =
               WordBooks.share_word_book(stranger.id, word_book.id, recipient.id)
    end

    test "rejects when users are not mutual followers", %{
      sender: sender,
      stranger: stranger,
      word_book: word_book
    } do
      assert {:error, :not_mutual} =
               WordBooks.share_word_book(sender.id, word_book.id, stranger.id)
    end

    test "rejects duplicate pending share", %{
      sender: sender,
      recipient: recipient,
      word_book: word_book
    } do
      assert {:ok, _} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)

      assert {:error, :already_shared} =
               WordBooks.share_word_book(sender.id, word_book.id, recipient.id)
    end
  end

  describe "accept_word_book_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word1 = word_fixture()
      word2 = word_fixture()

      word_book =
        word_book_fixture(%{
          user_id: sender.id,
          title: "Shared Book",
          description: "A shared book",
          cover_image: "sakura",
          theme: "dark",
          card_shape: "square",
          cards_per_page: 2,
          front_background: "dots",
          back_background: "waves",
          custom_text: "Study hard",
          front_config: %{"show_word" => true, "meanings" => ["en"]},
          back_config: %{"show_reading" => true, "example_count" => 2}
        })

      word_book = word_book_with_words_fixture_from(word_book, [word1, word2])

      {:ok, share} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)

      %{
        sender: sender,
        recipient: recipient,
        word_book: word_book,
        share: share,
        words: [word1, word2]
      }
    end

    test "copies the word book with all presentation fields and words", %{
      recipient: recipient,
      word_book: word_book,
      share: share,
      words: words
    } do
      assert {:ok, copied_book} = WordBooks.accept_word_book_share(share.id, recipient.id)
      assert copied_book.user_id == recipient.id
      assert copied_book.title == word_book.title
      assert copied_book.description == word_book.description
      assert copied_book.cover_image == word_book.cover_image
      assert copied_book.theme == word_book.theme
      assert copied_book.card_shape == word_book.card_shape
      assert copied_book.cards_per_page == word_book.cards_per_page
      assert copied_book.front_background == word_book.front_background
      assert copied_book.back_background == word_book.back_background
      assert copied_book.custom_text == word_book.custom_text
      assert copied_book.front_config == word_book.front_config
      assert copied_book.back_config == word_book.back_config
      assert copied_book.word_count == 2

      copied = WordBooks.get_word_book!(copied_book.id)
      copied_word_ids = Enum.map(copied.word_book_words, & &1.word_id)
      assert copied_word_ids == Enum.map(words, & &1.id)
      assert Enum.map(copied.word_book_words, & &1.position) == [0, 1]

      share = WordBooks.get_word_book_share(share.id)
      assert share.status == "accepted"
    end

    test "rejects non-recipient acceptance", %{sender: sender, share: share} do
      assert {:error, :not_recipient} = WordBooks.accept_word_book_share(share.id, sender.id)
    end
  end

  describe "delete_word_book_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_book = word_book_fixture(%{user_id: sender.id})
      {:ok, share} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)

      %{sender: sender, recipient: recipient, share: share}
    end

    test "deletes share", %{recipient: recipient, share: share} do
      assert {:ok, deleted} = WordBooks.delete_word_book_share(share.id, recipient.id)
      assert deleted.id == share.id
      assert is_nil(WordBooks.get_word_book_share(share.id))
    end

    test "rejects non-recipient deletion", %{sender: sender, share: share} do
      assert {:error, :not_recipient} = WordBooks.delete_word_book_share(share.id, sender.id)
    end
  end

  describe "cancel_word_book_share/2" do
    setup do
      sender = user_fixture()
      recipient = user_fixture()

      Social.follow_user(sender.id, recipient.id)
      Social.follow_user(recipient.id, sender.id)

      word_book = word_book_fixture(%{user_id: sender.id})
      {:ok, share} = WordBooks.share_word_book(sender.id, word_book.id, recipient.id)

      %{sender: sender, recipient: recipient, share: share}
    end

    test "marks share as cancelled", %{recipient: recipient, share: share} do
      assert {:ok, cancelled} = WordBooks.cancel_word_book_share(share.id, recipient.id)
      assert cancelled.status == "cancelled"
    end
  end

  # Adds words to an existing book, threading the returned struct (add_word_to_book
  # computes counts from the passed struct).
  defp word_book_with_words_fixture_from(word_book, words) do
    Enum.reduce(words, word_book, fn word, book ->
      {:ok, book} = WordBooks.add_word_to_book(book, word.id)
      book
    end)
  end
end
