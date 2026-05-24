defmodule Medoru.Chat do
  @moduledoc """
  The Chat context.

  Handles conversations, messages, typing indicators, and read receipts.
  All messages are stored as ciphertext — the server never sees plaintext.
  Supports both 1:1 and group conversations.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.PubSub

  alias Medoru.Chat.{Conversation, ConversationParticipant, Message, ConversationKey}

  # ============================================================================
  # Conversations
  # ============================================================================

  @doc """
  Lists all conversations for a user, sorted by most recent message.
  """
  def list_conversations(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    offset = Keyword.get(opts, :offset, 0)

    Conversation
    |> join(:inner, [c], cp in ConversationParticipant, on: cp.conversation_id == c.id)
    |> where([c, cp], cp.user_id == ^user_id and cp.has_left == false)
    |> preload(participants: [user: :profile])
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&enrich_with_last_message/1)
  end

  @doc """
  Gets a single conversation and verifies the user is a participant.
  """
  def get_conversation(user_id, conversation_id) do
    conversation =
      Conversation
      |> Repo.get(conversation_id)
      |> Repo.preload(participants: [user: :profile])

    case conversation do
      nil ->
        nil

      conv ->
        if Enum.any?(conv.participants, &(&1.user_id == user_id)) do
          enrich_with_last_message(conv)
        else
          nil
        end
    end
  end

  @doc """
  Finds an existing 1:1 conversation between two users, or creates one.
  """
  def find_or_create_conversation(user_a_id, user_b_id) do
    user_ids = Enum.sort([user_a_id, user_b_id])

    existing =
      Conversation
      |> join(:inner, [c], cp in ConversationParticipant, on: cp.conversation_id == c.id)
      |> where([c, cp], cp.user_id in ^user_ids)
      |> where([c], c.is_group == false)
      |> group_by([c], c.id)
      |> having([c, cp], count(cp.id) == 2)
      |> preload(participants: [user: :profile])
      |> Repo.one()

    case existing do
      nil -> create_conversation(user_ids)
      conv -> {:ok, enrich_with_last_message(conv)}
    end
  end

  @doc """
  Creates a new group conversation with multiple participants.
  The creator must provide encrypted conversation keys for each participant.
  """
  def create_group_conversation(creator_id, title, user_ids, encrypted_keys) do
    all_user_ids = Enum.uniq([creator_id | user_ids])
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      conversation =
        %Conversation{}
        |> Conversation.changeset(%{
          title: title,
          is_group: true,
          started_at: now
        })
        |> Repo.insert!()

      # Add all participants
      for user_id <- all_user_ids do
        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: user_id,
          joined_at: now
        })
        |> Repo.insert!()
      end

      # Store encrypted conversation keys for each participant
      for {user_id, encrypted_key} <- encrypted_keys do
        %ConversationKey{}
        |> ConversationKey.changeset(%{
          conversation_id: conversation.id,
          user_id: user_id,
          encrypted_key: Base.decode64!(encrypted_key)
        })
        |> Repo.insert!()
      end

      conversation
      |> Repo.preload(participants: [user: :profile])
      |> enrich_with_last_message()
    end)
  end

  defp create_conversation(user_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      conversation =
        %Conversation{}
        |> Conversation.changeset(%{started_at: now})
        |> Repo.insert!()

      for user_id <- user_ids do
        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: user_id,
          joined_at: now
        })
        |> Repo.insert!()
      end

      conversation
      |> Repo.preload(participants: [user: :profile])
      |> enrich_with_last_message()
    end)
  end

  @doc """
  Adds a participant to an existing group conversation.
  Stores the encrypted conversation key for the new participant.
  """
  def add_participant(conversation_id, user_id, encrypted_key_b64) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      %ConversationParticipant{}
      |> ConversationParticipant.changeset(%{
        conversation_id: conversation_id,
        user_id: user_id,
        joined_at: now
      })
      |> Repo.insert!()

      %ConversationKey{}
      |> ConversationKey.changeset(%{
        conversation_id: conversation_id,
        user_id: user_id,
        encrypted_key: Base.decode64!(encrypted_key_b64)
      })
      |> Repo.insert!()
    end)
  end

  defp enrich_with_last_message(conversation) do
    last_message =
      Message
      |> where([m], m.conversation_id == ^conversation.id)
      |> order_by([m], desc: m.inserted_at)
      |> limit(1)
      |> Repo.one()

    Map.put(conversation, :last_message, last_message)
  end

  # ============================================================================
  # Conversation Keys
  # ============================================================================

  @doc """
  Gets the encrypted conversation key for a user in a conversation.
  Returns nil if not found.
  """
  def get_conversation_key(conversation_id, user_id) do
    ConversationKey
    |> where([ck], ck.conversation_id == ^conversation_id and ck.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets all encrypted conversation keys for a conversation.
  Used when the creator sends encrypted keys for all participants.
  """
  def list_conversation_keys(conversation_id) do
    ConversationKey
    |> where([ck], ck.conversation_id == ^conversation_id)
    |> Repo.all()
  end

  @doc """
  Stores an encrypted conversation key for a user.
  """
  def store_conversation_key(conversation_id, user_id, encrypted_key_b64) do
    %ConversationKey{}
    |> ConversationKey.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id,
      encrypted_key: Base.decode64!(encrypted_key_b64)
    })
    |> Repo.insert()
  end

  # ============================================================================
  # Messages
  # ============================================================================

  @doc """
  Lists messages for a conversation, newest first.
  """
  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(sender: [:profile], reply_to_message: [sender: [:profile]])
    |> Repo.all()
  end

  @doc """
  Stores an encrypted message.
  Accepts base64-encoded ciphertext and IV.
  """
  def store_message(conversation_id, sender_id, ciphertext_b64, iv_b64, opts \\ []) do
    reply_to_id = Keyword.get(opts, :reply_to_message_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ciphertext = Base.decode64!(ciphertext_b64)
    iv = Base.decode64!(iv_b64)

    attrs = %{
      conversation_id: conversation_id,
      sender_id: sender_id,
      ciphertext: ciphertext,
      iv: iv,
      encrypted_at: now,
      reply_to_message_id: reply_to_id
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = Repo.preload(message, sender: [:profile], reply_to_message: [sender: [:profile]])
        broadcast_message(conversation_id, message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id) do
    Message
    |> Repo.get!(id)
    |> Repo.preload(sender: [:profile], reply_to_message: [sender: [:profile]])
  end

  @doc """
  Gets the other participant in a 1:1 conversation.
  Returns nil for group conversations.
  """
  def get_other_participant(conversation, user_id) do
    if conversation.is_group do
      nil
    else
      conversation.participants
      |> Enum.reject(&(&1.user_id == user_id))
      |> List.first()
    end
  end

  @doc """
  Returns all participants except the given user.
  """
  def get_other_participants(conversation, user_id) do
    conversation.participants
    |> Enum.reject(&(&1.user_id == user_id))
  end

  @doc """
  Counts unread messages in a conversation for a user.
  """
  def count_unread_messages(conversation_id, user_id) do
    participant =
      ConversationParticipant
      |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
      |> Repo.one()

    last_read = participant && participant.last_read_at

    query =
      Message
      |> where([m], m.conversation_id == ^conversation_id and m.sender_id != ^user_id)

    query =
      if last_read do
        where(query, [m], m.inserted_at > ^last_read)
      else
        query
      end

    Repo.aggregate(query, :count, :id)
  end

  @doc """
  Counts total unread conversations for a user.
  """
  def count_unread_conversations(user_id) do
    Conversation
    |> join(:inner, [c], cp in ConversationParticipant, on: cp.conversation_id == c.id)
    |> where([c, cp], cp.user_id == ^user_id and cp.has_left == false)
    |> preload(participants: [user: :profile])
    |> Repo.all()
    |> Enum.count(fn conv ->
      count_unread_messages(conv.id, user_id) > 0
    end)
  end

  # ============================================================================
  # Read Receipts
  # ============================================================================

  @doc """
  Marks a conversation as read for a user.
  """
  def mark_read(user_id, conversation_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ConversationParticipant
    |> where([cp], cp.user_id == ^user_id and cp.conversation_id == ^conversation_id)
    |> Repo.update_all(set: [last_read_at: now])

    broadcast_read_receipt(conversation_id, user_id, now)

    :ok
  end

  # ============================================================================
  # Typing Indicators
  # ============================================================================

  @doc """
  Sets typing status for a user in a conversation.
  """
  def set_typing(user_id, conversation_id, is_typing) do
    ConversationParticipant
    |> where([cp], cp.user_id == ^user_id and cp.conversation_id == ^conversation_id)
    |> Repo.update_all(set: [is_typing: is_typing])

    broadcast_typing(conversation_id, user_id, is_typing)

    :ok
  end

  # ============================================================================
  # PubSub Broadcasting
  # ============================================================================

  defp broadcast_message(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:new_message, message}
    )
  end

  defp broadcast_typing(conversation_id, user_id, is_typing) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:typing, user_id, is_typing}
    )
  end

  defp broadcast_read_receipt(conversation_id, user_id, read_at) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:read_receipt, user_id, read_at}
    )
  end

  @doc """
  Subscribes to a conversation's PubSub topic.
  """
  def subscribe_to_conversation(conversation_id) do
    Phoenix.PubSub.subscribe(PubSub, "chat:#{conversation_id}")
  end

  @doc """
  Unsubscribes from a conversation's PubSub topic.
  """
  def unsubscribe_from_conversation(conversation_id) do
    Phoenix.PubSub.unsubscribe(PubSub, "chat:#{conversation_id}")
  end
end
