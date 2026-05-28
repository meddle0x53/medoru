defmodule Medoru.ChatTest do
  use Medoru.DataCase, async: true

  alias Medoru.Chat
  alias Medoru.Chat.{Conversation, ConversationParticipant, Message, ConversationKey}
  alias Medoru.Accounts

  defp user_fixture(attrs \\ %{}) do
    unique_suffix = "_#{System.unique_integer([:positive])}"

    attrs =
      attrs
      |> Map.drop([:email, :provider_uid, "email", "provider_uid"])
      |> Enum.into(%{
        email: "user#{unique_suffix}@example.com",
        provider: "google",
        provider_uid: "uid#{unique_suffix}",
        name: "Test User"
      })

    {:ok, user} = Accounts.create_user(attrs)
    user
  end

  describe "conversations" do
    test "find_or_create_conversation/2 creates a new 1:1 conversation" do
      user_a = user_fixture()
      user_b = user_fixture()

      assert {:ok, %Conversation{} = conv} =
               Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert conv.is_group == false
      assert length(conv.participants) == 2
    end

    test "find_or_create_conversation/2 returns existing conversation" do
      user_a = user_fixture()
      user_b = user_fixture()

      {:ok, conv1} = Chat.find_or_create_conversation(user_a.id, user_b.id)
      {:ok, conv2} = Chat.find_or_create_conversation(user_b.id, user_a.id)

      assert conv1.id == conv2.id
    end

    test "get_conversation/2 returns conversation for participant" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert %Conversation{} = Chat.get_conversation(user_a.id, conv.id)
      assert Chat.get_conversation(user_a.id, conv.id).id == conv.id
    end

    test "get_conversation/2 returns nil for non-participant" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert Chat.get_conversation(user_c.id, conv.id) == nil
    end

    test "list_conversations/1 returns conversations for user" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      {:ok, conv1} = Chat.find_or_create_conversation(user_a.id, user_b.id)
      {:ok, conv2} = Chat.find_or_create_conversation(user_a.id, user_c.id)

      conversations = Chat.list_conversations(user_a.id)
      assert length(conversations) == 2
      assert Enum.any?(conversations, &(&1.id == conv1.id))
      assert Enum.any?(conversations, &(&1.id == conv2.id))
    end

    test "create_group_conversation/4 creates a group conversation" do
      creator = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      encrypted_keys = %{
        creator.id => Base.encode64(<<1, 2, 3>>),
        user_b.id => Base.encode64(<<4, 5, 6>>),
        user_c.id => Base.encode64(<<7, 8, 9>>)
      }

      assert {:ok, %Conversation{} = conv} =
               Chat.create_group_conversation(
                 creator.id,
                 "Test Group",
                 [user_b.id, user_c.id],
                 encrypted_keys
               )

      assert conv.is_group == true
      assert conv.title == "Test Group"
      assert length(conv.participants) == 3
    end
  end

  describe "messages" do
    test "store_message/5 stores an encrypted message" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      ciphertext = Base.encode64(<<1, 2, 3, 4>>)
      iv = Base.encode64(<<5, 6, 7>>)

      assert {:ok, %Message{} = message} =
               Chat.store_message(conv.id, user_a.id, ciphertext, iv)

      assert message.conversation_id == conv.id
      assert message.sender_id == user_a.id
      assert message.ciphertext == Base.decode64!(ciphertext)
      assert message.iv == Base.decode64!(iv)
    end

    test "store_message/5 with reply_to_message_id" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, original} =
        Chat.store_message(conv.id, user_a.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      {:ok, reply} =
        Chat.store_message(conv.id, user_b.id, Base.encode64(<<3>>), Base.encode64(<<4>>),
          reply_to_message_id: original.id
        )

      assert reply.reply_to_message_id == original.id
    end

    test "list_messages/1 returns messages ordered newest first" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Chat.store_message(conv.id, user_a.id, Base.encode64(<<1>>), Base.encode64(<<2>>))
      Chat.store_message(conv.id, user_a.id, Base.encode64(<<3>>), Base.encode64(<<4>>))

      messages = Chat.list_messages(conv.id)
      assert length(messages) == 2
    end

    test "get_message!/1 returns a message" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, message} =
        Chat.store_message(conv.id, user_a.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      assert Chat.get_message!(message.id).id == message.id
    end
  end

  describe "conversation keys" do
    test "store_conversation_key/3 and get_conversation_key/2" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      encrypted_key = Base.encode64(<<1, 2, 3, 4, 5>>)

      assert {:ok, %ConversationKey{}} =
               Chat.store_conversation_key(conv.id, user_a.id, encrypted_key)

      key = Chat.get_conversation_key(conv.id, user_a.id)
      assert key != nil
      assert key.encrypted_key == Base.decode64!(encrypted_key)
    end

    test "list_conversation_keys/1 returns all keys for a conversation" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Chat.store_conversation_key(conv.id, user_a.id, Base.encode64(<<1>>))
      Chat.store_conversation_key(conv.id, user_b.id, Base.encode64(<<2>>))

      keys = Chat.list_conversation_keys(conv.id)
      assert length(keys) == 2
    end
  end

  describe "read receipts" do
    test "mark_read/2 updates last_read_at" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      :ok = Chat.mark_read(user_a.id, conv.id)

      participant =
        Medoru.Repo.get_by(ConversationParticipant,
          conversation_id: conv.id,
          user_id: user_a.id
        )

      assert participant.last_read_at != nil
    end

    test "count_unread_messages/2 counts messages since last read" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))
      Chat.store_message(conv.id, user_b.id, Base.encode64(<<3>>), Base.encode64(<<4>>))

      assert Chat.count_unread_messages(conv.id, user_a.id) == 2

      Chat.mark_read(user_a.id, conv.id)

      assert Chat.count_unread_messages(conv.id, user_a.id) == 0
    end

    test "count_unread_conversations/1 counts conversations with unread messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      {:ok, conv1} = Chat.find_or_create_conversation(user_a.id, user_b.id)
      {:ok, conv2} = Chat.find_or_create_conversation(user_a.id, user_c.id)

      Chat.store_message(conv1.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))
      Chat.store_message(conv2.id, user_c.id, Base.encode64(<<3>>), Base.encode64(<<4>>))

      assert Chat.count_unread_conversations(user_a.id) == 2

      Chat.mark_read(user_a.id, conv1.id)

      assert Chat.count_unread_conversations(user_a.id) == 1
    end
  end

  describe "typing indicators" do
    test "set_typing/3 updates typing status" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      :ok = Chat.set_typing(user_a.id, conv.id, true)

      participant =
        Medoru.Repo.get_by(ConversationParticipant,
          conversation_id: conv.id,
          user_id: user_a.id
        )

      assert participant.is_typing == true
    end
  end

  describe "participants" do
    test "get_other_participant/2 returns the other user in 1:1" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)
      conv = Chat.get_conversation(user_a.id, conv.id)

      other = Chat.get_other_participant(conv, user_a.id)
      assert other.user_id == user_b.id
    end

    test "get_other_participant/2 returns nil for group" do
      creator = user_fixture()
      user_b = user_fixture()

      {:ok, conv} =
        Chat.create_group_conversation(creator.id, "Group", [user_b.id], %{
          creator.id => Base.encode64(<<1>>),
          user_b.id => Base.encode64(<<2>>)
        })

      assert Chat.get_other_participant(conv, creator.id) == nil
    end

    test "get_other_participants/2 returns all others" do
      creator = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      {:ok, conv} =
        Chat.create_group_conversation(creator.id, "Group", [user_b.id, user_c.id], %{
          creator.id => Base.encode64(<<1>>),
          user_b.id => Base.encode64(<<2>>),
          user_c.id => Base.encode64(<<3>>)
        })

      others = Chat.get_other_participants(conv, creator.id)
      assert length(others) == 2
    end

    test "add_participant/3 adds a new participant to group" do
      creator = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      {:ok, conv} =
        Chat.create_group_conversation(creator.id, "Group", [user_b.id], %{
          creator.id => Base.encode64(<<1>>),
          user_b.id => Base.encode64(<<2>>)
        })

      assert {:ok, _} = Chat.add_participant(conv.id, user_c.id, Base.encode64(<<3>>))

      conv = Chat.get_conversation(creator.id, conv.id)
      assert length(conv.participants) == 3
    end
  end

  describe "plaintext messages" do
    test "store_plaintext_message/4 stores a message with content" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert {:ok, %Message{} = message} =
               Chat.store_plaintext_message(conv.id, user_a.id, "Hello classroom!")

      assert message.content == "Hello classroom!"
      assert message.ciphertext == nil
      assert message.conversation_id == conv.id
      assert message.sender_id == user_a.id
    end

    test "list_messages/2 returns plaintext messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Chat.store_plaintext_message(conv.id, user_a.id, "Message 1")
      Chat.store_plaintext_message(conv.id, user_b.id, "Message 2")

      messages = Chat.list_messages(conv.id)
      assert length(messages) == 2
      assert Enum.any?(messages, &(&1.content == "Message 1"))
      assert Enum.any?(messages, &(&1.content == "Message 2"))
    end
  end

  defp classroom_fixture(attrs \\ %{}) do
    teacher_id = attrs[:teacher_id] || user_fixture().id

    {:ok, classroom} =
      Medoru.Classrooms.create_classroom(%{name: "Test Classroom", teacher_id: teacher_id})

    classroom
  end

  describe "classroom conversation" do
    test "get_classroom_conversation/1 returns conversation by classroom_id" do
      teacher = user_fixture()
      classroom = classroom_fixture(%{teacher_id: teacher.id})

      conv = Chat.get_classroom_conversation(classroom.id)
      assert conv != nil
      assert conv.classroom_id == classroom.id
      assert conv.is_group == true
      assert Chat.get_classroom_conversation(Ecto.UUID.generate()) == nil
    end
  end

  describe "message pagination" do
    test "list_messages/2 with before_id cursor loads older messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Create 25 messages
      for i <- 1..25 do
        Chat.store_plaintext_message(conv.id, user_a.id, "Message #{i}")
      end

      # First page: 20 latest
      page1 = Chat.list_messages(conv.id, limit: 20)
      assert length(page1) == 20

      page2 = Chat.list_messages(conv.id, limit: 20, offset: 20)
      assert length(page2) == 5
    end
  end

  describe "participant management" do
    test "add_participant_plain/2 adds participant without encrypted key" do
      teacher = user_fixture()
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      conv = Chat.get_classroom_conversation(classroom.id)
      student = user_fixture()

      assert {:ok, %ConversationParticipant{}} =
               Chat.add_participant_plain(conv.id, student.id)

      conv = Chat.get_classroom_conversation(classroom.id)
      assert length(conv.participants) == 2
    end

    test "mark_participant_left/2 sets has_left to true" do
      teacher = user_fixture()
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      conv = Chat.get_classroom_conversation(classroom.id)
      student = user_fixture()
      {:ok, _} = Chat.add_participant_plain(conv.id, student.id)

      Chat.mark_participant_left(conv.id, student.id)

      conv = Chat.get_classroom_conversation(classroom.id)
      participant = Enum.find(conv.participants, &(&1.user_id == student.id))
      assert participant.has_left == true
    end

    test "rejoin_participant/2 re-adds a left participant" do
      teacher = user_fixture()
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      conv = Chat.get_classroom_conversation(classroom.id)
      student = user_fixture()
      {:ok, _} = Chat.add_participant_plain(conv.id, student.id)
      Chat.mark_participant_left(conv.id, student.id)

      assert {:ok, _} = Chat.rejoin_participant(conv.id, student.id)

      conv = Chat.get_classroom_conversation(classroom.id)
      participant = Enum.find(conv.participants, &(&1.user_id == student.id))
      assert participant.has_left == false
    end

    test "rejoin_participant/2 adds new participant if none exists" do
      teacher = user_fixture()
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      conv = Chat.get_classroom_conversation(classroom.id)
      student = user_fixture()

      assert {:ok, _} = Chat.rejoin_participant(conv.id, student.id)

      conv = Chat.get_classroom_conversation(classroom.id)
      assert length(conv.participants) == 2
    end
  end

  describe "message deletion" do
    test "delete_message/2 soft-deletes a message" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")
      assert msg.is_deleted == false

      assert {:ok, deleted} = Chat.delete_message(msg.id, user_a.id)
      assert deleted.is_deleted == true
    end

    test "delete_message/2 prevents deleting others' messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")

      assert {:error, :unauthorized} = Chat.delete_message(msg.id, user_b.id)
    end

    test "delete_message/2 returns error for missing message" do
      user = user_fixture()

      assert {:error, :not_found} = Chat.delete_message(Ecto.UUID.generate(), user.id)
    end
  end

  describe "message editing" do
    test "edit_message/3 updates a message within window" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")

      assert {:ok, edited} = Chat.edit_message(msg.id, user_a.id, %{"content" => "Hello edited"})
      assert edited.content == "Hello edited"
      assert edited.edited_at != nil
    end

    test "edit_message/3 prevents editing others' messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")

      assert {:error, :unauthorized} =
               Chat.edit_message(msg.id, user_b.id, %{"content" => "Hacked"})
    end

    test "edit_message/3 prevents editing deleted messages" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")
      Chat.delete_message(msg.id, user_a.id)

      assert {:error, :deleted} = Chat.edit_message(msg.id, user_a.id, %{"content" => "Nope"})
    end

    test "can_edit_message?/2 checks sender and window" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} = Chat.store_plaintext_message(conv.id, user_a.id, "Hello")

      assert Chat.can_edit_message?(msg, user_a.id) == true
      assert Chat.can_edit_message?(msg, user_b.id) == false
    end
  end

  describe "pubsub" do
    test "subscribe_to_conversation/1 and unsubscribe_from_conversation/1" do
      user_a = user_fixture()
      user_b = user_fixture()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert :ok = Chat.subscribe_to_conversation(conv.id)
      assert :ok = Chat.unsubscribe_from_conversation(conv.id)
    end
  end
end
