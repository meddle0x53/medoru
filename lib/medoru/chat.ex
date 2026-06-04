defmodule Medoru.Chat do
  @moduledoc """
  The Chat context.

  Handles conversations, messages, typing indicators, and read receipts.
  Supports encrypted 1:1 and group conversations (ciphertext only server-side),
  as well as plaintext classroom chats.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.PubSub

  alias Medoru.Chat.{Conversation, ConversationParticipant, Message, ConversationKey}
  alias Medoru.Notifications
  alias Medoru.Social
  alias MedoruWeb.Presence

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
    |> where([c, cp], cp.user_id == ^user_id and cp.has_left == false and cp.is_archived == false)
    |> preload([:classroom, participants: [user: :profile]])
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&enrich_with_last_message/1)
    |> Enum.reject(fn conv ->
      if conv.is_group do
        false
      else
        other = get_other_participant(conv, user_id)
        other && Medoru.Social.is_blocked?(user_id, other.user_id) == :blocked
      end
    end)
  end

  @doc """
  Gets a single conversation and verifies the user is a participant.
  """
  def get_conversation(user_id, conversation_id) do
    conversation =
      Conversation
      |> Repo.get(conversation_id)
      |> Repo.preload([:classroom, participants: [user: :profile]])

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

    # Check for bidirectional blocks between any pair of participants
    for a <- all_user_ids, b <- all_user_ids, a < b do
      if Social.is_blocked?(a, b) == :blocked do
        raise Ecto.InvalidChangesetError,
          changeset: %Ecto.Changeset{errors: [base: {"blocked participants", []}]}
      end
    end

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

      # Store encrypted conversation keys for each participant.
      # Supports both legacy single-key format and multi-key format.
      for {user_id, entries} <- encrypted_keys do
        cond do
          is_list(entries) and entries != [] and is_map(hd(entries)) ->
            # New multi-key format: [%{"fingerprint" => fp, "encrypted_key" => b64}, ...]
            for %{"fingerprint" => fp, "encrypted_key" => key_b64} <- entries do
              %ConversationKey{}
              |> ConversationKey.changeset(%{
                conversation_id: conversation.id,
                user_id: user_id,
                encrypted_key: Base.decode64!(key_b64),
                key_fingerprint: fp
              })
              |> Repo.insert!()
            end

          is_binary(entries) ->
            # Legacy single-key format: "base64_key"
            %ConversationKey{}
            |> ConversationKey.changeset(%{
              conversation_id: conversation.id,
              user_id: user_id,
              encrypted_key: Base.decode64!(entries)
            })
            |> Repo.insert!()

          true ->
            :ok
        end
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
  Returns nil if not found. Backward-compat: returns a single row.
  """
  def get_conversation_key(conversation_id, user_id) do
    # Backward compat: prefer the legacy row (nil fingerprint) if one exists,
    # otherwise return the most recently inserted row.
    ConversationKey
    |> where([ck], ck.conversation_id == ^conversation_id and ck.user_id == ^user_id)
    |> order_by([ck], asc: ck.key_fingerprint)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets all encrypted conversation keys for a user in a conversation.
  Multi-device support: returns a list of keys (one per fingerprint).
  """
  def get_conversation_keys(conversation_id, user_id) do
    ConversationKey
    |> where([ck], ck.conversation_id == ^conversation_id and ck.user_id == ^user_id)
    |> Repo.all()
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
  Accepts an optional key_fingerprint for multi-device support.
  """
  def store_conversation_key(conversation_id, user_id, encrypted_key_b64, key_fingerprint \\ nil) do
    %ConversationKey{}
    |> ConversationKey.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id,
      encrypted_key: Base.decode64!(encrypted_key_b64),
      key_fingerprint: key_fingerprint
    })
    |> Repo.insert()
  end

  @doc """
  Updates or inserts an encrypted conversation key for a user.
  Used when a participant's public key changes and the key needs re-encryption.
  Accepts an optional key_fingerprint for multi-device support.
  """
  def upsert_conversation_key(conversation_id, user_id, encrypted_key_b64, key_fingerprint \\ nil) do
    encrypted_key = Base.decode64!(encrypted_key_b64)

    # Look for an existing row with the same fingerprint
    existing =
      ConversationKey
      |> where([ck], ck.conversation_id == ^conversation_id and ck.user_id == ^user_id)
      |> where([ck], ck.key_fingerprint == ^key_fingerprint)
      |> Repo.one()

    cond do
      existing != nil ->
        existing
        |> ConversationKey.changeset(%{encrypted_key: encrypted_key})
        |> Repo.update()

      key_fingerprint == nil ->
        # Backward compat: upsert the legacy row (no fingerprint)
        case get_conversation_key(conversation_id, user_id) do
          nil ->
            %ConversationKey{}
            |> ConversationKey.changeset(%{
              conversation_id: conversation_id,
              user_id: user_id,
              encrypted_key: encrypted_key
            })
            |> Repo.insert()

          legacy ->
            legacy
            |> ConversationKey.changeset(%{encrypted_key: encrypted_key})
            |> Repo.update()
        end

      true ->
        %ConversationKey{}
        |> ConversationKey.changeset(%{
          conversation_id: conversation_id,
          user_id: user_id,
          encrypted_key: encrypted_key,
          key_fingerprint: key_fingerprint
        })
        |> Repo.insert()
    end
  end

  @doc """
  Deletes all conversation keys for a conversation.
  Used as a last resort when all participants have lost their private keys
  and need to create a fresh shared encryption key.
  """
  def delete_conversation_keys(conversation_id) do
    ConversationKey
    |> where([ck], ck.conversation_id == ^conversation_id)
    |> Repo.delete_all()
  end

  # ============================================================================
  # Messages
  # ============================================================================

  @doc """
  Lists messages for a conversation, newest first.

  Supports pagination via `:offset` (for loading older messages).
  Default limit is 20 messages.
  """
  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(sender: [:profile], reply_to_message: [sender: [:profile]])
    |> Repo.all()
    |> Enum.reverse()
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
      reply_to_message_id: reply_to_id,
      attachment_path: Keyword.get(opts, :attachment_path),
      attachment_type: Keyword.get(opts, :attachment_type),
      duration_seconds: Keyword.get(opts, :duration_seconds)
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message =
          Repo.preload(message, sender: [:profile], reply_to_message: [sender: [:profile]])

        broadcast_message(conversation_id, message)
        maybe_notify_participants(conversation_id, sender_id, message)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Stores a plaintext message (for classroom chats).
  """
  def store_plaintext_message(conversation_id, sender_id, content, opts \\ []) do
    reply_to_id = Keyword.get(opts, :reply_to_message_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      conversation_id: conversation_id,
      sender_id: sender_id,
      content: content,
      encrypted_at: now,
      reply_to_message_id: reply_to_id,
      attachment_path: Keyword.get(opts, :attachment_path),
      attachment_type: Keyword.get(opts, :attachment_type),
      duration_seconds: Keyword.get(opts, :duration_seconds)
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message =
          Repo.preload(message, sender: [:profile], reply_to_message: [sender: [:profile]])

        broadcast_message(conversation_id, message)
        maybe_notify_participants(conversation_id, sender_id, message)
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
  Soft-deletes a message. Only the sender can delete their own message.
  """
  def delete_message(message_id, user_id) do
    message = Repo.get(Message, message_id)

    cond do
      is_nil(message) ->
        {:error, :not_found}

      message.sender_id != user_id ->
        {:error, :unauthorized}

      message.is_deleted ->
        {:ok, message}

      true ->
        message
        |> Message.changeset(%{is_deleted: true})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            broadcast_message_deleted(message.conversation_id, message_id)
            {:ok, updated}

          error ->
            error
        end
    end
  end

  @doc """
  Edits a message. Only the sender can edit, and only within 15 minutes of sending.
  For encrypted messages, the client must provide new ciphertext and IV.
  For plaintext messages, the client provides new content.
  """
  def edit_message(message_id, user_id, attrs) do
    message = Repo.get(Message, message_id)

    cond do
      is_nil(message) ->
        {:error, :not_found}

      message.sender_id != user_id ->
        {:error, :unauthorized}

      message.is_deleted ->
        {:error, :deleted}

      not within_edit_window?(message) ->
        {:error, :edit_window_expired}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        update_attrs =
          attrs
          |> Map.put("edited_at", now)
          |> Map.put_new("ciphertext", message.ciphertext)
          |> Map.put_new("iv", message.iv)
          |> Map.put_new("content", message.content)

        message
        |> Message.changeset(update_attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            updated =
              Repo.preload(updated, sender: [:profile], reply_to_message: [sender: [:profile]])

            broadcast_message_edited(message.conversation_id, updated)
            {:ok, updated}

          error ->
            error
        end
    end
  end

  defp within_edit_window?(%Message{inserted_at: inserted_at}) do
    edit_window_minutes = 15
    cutoff = DateTime.add(inserted_at, edit_window_minutes, :minute)
    DateTime.compare(DateTime.utc_now(), cutoff) != :gt
  end

  @doc """
  Checks if a message can be edited by the given user.
  """
  def can_edit_message?(
        %Message{sender_id: sender_id, is_deleted: is_deleted, inserted_at: inserted_at},
        user_id
      ) do
    sender_id == user_id &&
      not is_deleted &&
      within_edit_window?(%Message{inserted_at: inserted_at})
  end

  @doc """
  Checks if a message can be deleted by the given user.
  """
  def can_delete_message?(%Message{sender_id: sender_id, is_deleted: is_deleted}, user_id) do
    sender_id == user_id && not is_deleted
  end

  @doc """
  Gets the conversation linked to a classroom.
  Returns nil if no classroom chat exists.
  """
  def get_classroom_conversation(classroom_id) do
    Conversation
    |> where([c], c.classroom_id == ^classroom_id)
    |> preload(participants: [user: :profile])
    |> Repo.one()
  end

  @doc """
  Marks a participant as having left a group conversation.
  """
  def leave_conversation(conversation_id, user_id) do
    ConversationParticipant
    |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
    |> Repo.update_all(set: [has_left: true])

    :ok
  end

  @doc """
  Archives a conversation for a user (hides it from their list without deleting data).
  """
  def archive_conversation(conversation_id, user_id) do
    ConversationParticipant
    |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
    |> Repo.update_all(set: [is_archived: true])

    :ok
  end

  @doc """
  Unarchives a conversation for a user.
  """
  def unarchive_conversation(conversation_id, user_id) do
    ConversationParticipant
    |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
    |> Repo.update_all(set: [is_archived: false])

    :ok
  end

  @doc """
  Creates a classroom conversation and adds the teacher as the first participant.
  """
  def create_classroom_conversation(classroom) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      conversation =
        %Conversation{}
        |> Conversation.changeset(%{
          title: classroom.name,
          is_group: true,
          classroom_id: classroom.id,
          started_at: now
        })
        |> Repo.insert!()

      # Add teacher as first participant
      %ConversationParticipant{}
      |> ConversationParticipant.changeset(%{
        conversation_id: conversation.id,
        user_id: classroom.teacher_id,
        joined_at: now
      })
      |> Repo.insert!()

      conversation
      |> Repo.preload(participants: [user: :profile])
    end)
  end

  @doc """
  Adds a participant to a conversation without requiring an encrypted key.
  Used for classroom chats where encryption is not used.
  """
  def add_participant_plain(conversation_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %ConversationParticipant{}
    |> ConversationParticipant.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id,
      joined_at: now
    })
    |> Repo.insert()
  end

  @doc """
  Marks a participant as having left a conversation.
  """
  def mark_participant_left(conversation_id, user_id) do
    ConversationParticipant
    |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
    |> Repo.update_all(set: [has_left: true])
  end

  @doc """
  Re-adds a participant who previously left a conversation.
  """
  def rejoin_participant(conversation_id, user_id) do
    case ConversationParticipant
         |> where([cp], cp.conversation_id == ^conversation_id and cp.user_id == ^user_id)
         |> Repo.one() do
      nil ->
        add_participant_plain(conversation_id, user_id)

      participant ->
        participant
        |> ConversationParticipant.changeset(%{has_left: false})
        |> Repo.update()
    end
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

  defp broadcast_message_deleted(conversation_id, message_id) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:message_deleted, message_id}
    )
  end

  defp broadcast_message_edited(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:message_edited, message}
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

  @doc """
  Broadcasts a request for other participants to re-encrypt the conversation key
  for a user whose public key has changed.
  """
  def broadcast_key_reencryption_request(
        conversation_id,
        target_user_id,
        preferred_key_b64 \\ nil
      ) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:request_key_reencryption, target_user_id, preferred_key_b64}
    )
  end

  @doc """
  Broadcasts a re-encrypted conversation key to a specific user.
  """
  def broadcast_reencrypted_key(conversation_id, target_user_id, encrypted_key_b64) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:reencrypted_key, target_user_id, encrypted_key_b64}
    )
  end

  @doc """
  Broadcasts that encryption has been reset so all clients clear their stale key cache.
  """
  def broadcast_encryption_reset(conversation_id) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:encryption_reset, conversation_id}
    )
  end

  # ============================================================================
  # Message Reactions
  # ============================================================================

  alias Medoru.Chat.MessageReaction

  @doc """
  Toggles a reaction on a message.
  Each user can have at most one reaction per message.
  - No existing reaction → adds the new one
  - Same emoji clicked → removes it
  - Different emoji clicked → replaces old with new
  Returns {:ok, added_reaction, removed_reaction} where either may be nil.
  """
  def toggle_reaction(message_id, user_id, emoji) do
    existing =
      Repo.one(
        from r in MessageReaction,
          where: r.message_id == ^message_id and r.user_id == ^user_id
      )

    cond do
      is_nil(existing) ->
        %MessageReaction{}
        |> MessageReaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji
        })
        |> Repo.insert()
        |> case do
          {:ok, reaction} -> {:ok, reaction, nil}
          error -> error
        end

      existing.emoji == emoji ->
        Repo.delete(existing)
        {:ok, nil, existing}

      true ->
        Repo.transaction(fn ->
          Repo.delete!(existing)

          %MessageReaction{}
          |> MessageReaction.changeset(%{
            message_id: message_id,
            user_id: user_id,
            emoji: emoji
          })
          |> Repo.insert!()
        end)
        |> case do
          {:ok, reaction} -> {:ok, reaction, existing}
          error -> error
        end
    end
  end

  @doc """
  Lists all reactions for a given message, grouped by emoji with user_ids.
  Returns a map: %{emoji => %{count: int, user_ids: [id], me?: bool}}
  """
  def list_reactions_for_message(message_id, current_user_id) do
    MessageReaction
    |> where([r], r.message_id == ^message_id)
    |> select([r], {r.emoji, r.user_id})
    |> Repo.all()
    |> Enum.group_by(fn {emoji, _user_id} -> emoji end, fn {_emoji, user_id} -> user_id end)
    |> Enum.map(fn {emoji, user_ids} ->
      {emoji,
       %{
         count: length(user_ids),
         user_ids: user_ids,
         me?: current_user_id in user_ids
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets reactions for multiple messages at once.
  Returns a map: %{message_id => %{emoji => %{count: int, me?: bool}}}
  """
  def list_reactions_for_messages(message_ids, current_user_id) do
    MessageReaction
    |> where([r], r.message_id in ^message_ids)
    |> select([r], {r.message_id, r.emoji, r.user_id})
    |> Repo.all()
    |> Enum.group_by(fn {msg_id, _emoji, _user_id} -> msg_id end)
    |> Enum.map(fn {msg_id, rows} ->
      grouped =
        rows
        |> Enum.group_by(fn {_msg_id, emoji, _user_id} -> emoji end, fn {_msg_id, _emoji, user_id} -> user_id end)
        |> Enum.map(fn {emoji, user_ids} ->
          {emoji,
           %{
             count: length(user_ids),
             me?: current_user_id in user_ids
           }}
        end)
        |> Enum.into(%{})

      {msg_id, grouped}
    end)
    |> Enum.into(%{})
  end

  def broadcast_reaction(conversation_id, message_id, user_id, emoji, added?) do
    Phoenix.PubSub.broadcast(
      PubSub,
      "chat:#{conversation_id}",
      {:reaction, message_id, user_id, emoji, added?}
    )
  end

  def broadcast_reaction_from(pid, conversation_id, message_id, user_id, emoji, added?) do
    Phoenix.PubSub.broadcast_from(
      PubSub,
      pid,
      "chat:#{conversation_id}",
      {:reaction, message_id, user_id, emoji, added?}
    )
  end

  # ============================================================================
  # Notifications
  # ============================================================================

  defp maybe_notify_participants(conversation_id, sender_id, message) do
    # Get active viewers (users currently looking at this chat on any device)
    active_viewers =
      Presence.list("chat_active:#{conversation_id}")
      |> Enum.map(fn {user_id, _} -> user_id end)
      |> MapSet.new()

    # Get conversation participants
    conversation =
      Conversation
      |> Repo.get(conversation_id)
      |> Repo.preload(participants: [user: :profile])

    if conversation do
      sender =
        conversation.participants
        |> Enum.find(&(&1.user_id == sender_id))
        |> case do
          nil -> "Someone"
          p -> (p.user.profile && p.user.profile.display_name) || p.user.name || "Someone"
        end

      body = notification_body_from_message(message)

      for participant <- conversation.participants,
          participant.user_id != sender_id,
          not participant.has_left,
          participant.user_id not in active_viewers do
        Notifications.notify_chat_message(
          participant.user_id,
          sender,
          conversation_id,
          conversation.is_group,
          conversation.title,
          body,
          conversation.classroom_id
        )

        # Send push notification
        title =
          if conversation.is_group do
            "#{sender} in #{conversation.title || "Group Chat"}"
          else
            sender
          end

        Notifications.send_push_notification(
          participant.user_id,
          title,
          body,
          %{conversation_id: conversation_id}
        )
      end
    end
  end

  defp notification_body_from_message(%{attachment_type: "voice"}), do: "Sent a voice message"
  defp notification_body_from_message(%{attachment_type: "image"}), do: "Sent an image"
  defp notification_body_from_message(%{attachment_type: "file"}), do: "Sent a file"

  defp notification_body_from_message(%{attachment_type: type}) when is_binary(type),
    do: "Sent an attachment"

  defp notification_body_from_message(%{content: content})
       when is_binary(content) and content != "" do
    if String.length(content) > 120 do
      String.slice(content, 0, 117) <> "..."
    else
      content
    end
  end

  defp notification_body_from_message(_message), do: "You have a new message"
end
