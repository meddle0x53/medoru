defmodule MedoruWeb.MessagesLive.Show do
  @moduledoc """
  LiveView for an individual chat conversation.

  Supports both encrypted conversations (1:1 and group chats) and
  plaintext classroom chats.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Social
  alias Medoru.Encryption
  alias MedoruWeb.Presence

  @per_page 20

  @impl true
  def mount(%{"id" => conversation_id}, session, socket) do
    locale = session["locale"] || "en"
    current_user = socket.assigns.current_scope.current_user

    if current_user do
      conversation = Chat.get_conversation(current_user.id, conversation_id)

      if conversation do
        if connected?(socket) do
          Chat.subscribe_to_conversation(conversation_id)
          Chat.mark_read(current_user.id, conversation_id)

          # Mark chat notifications for this conversation as read
          {:ok, _} = Medoru.Notifications.mark_chat_notifications_as_read(
            current_user.id,
            conversation_id
          )

          # Broadcast notification count update to dropdown
          unread_count = Medoru.Notifications.count_unread_notifications(current_user.id)
          Phoenix.PubSub.broadcast(
            Medoru.PubSub,
            "notifications:#{current_user.id}",
            {:unread_count_updated, unread_count}
          )

          # Track presence in this conversation and global online status
          Presence.track(self(), "chat_presence:#{conversation_id}", current_user.id, %{
            online_at: System.system_time(:second)
          })

          Presence.track(self(), "user_online:#{current_user.id}", "online", %{
            online_at: System.system_time(:second)
          })

          # Track active viewing for notification suppression
          Presence.track(self(), "chat_active:#{conversation_id}", current_user.id, %{
            joined_at: System.system_time(:second)
          })

          Phoenix.PubSub.subscribe(Medoru.PubSub, "chat_presence:#{conversation_id}")
        end

        online_user_ids = get_online_user_ids(conversation_id)

        other_participants = Chat.get_other_participants(conversation, current_user.id)

        is_blocked =
          if conversation.is_group do
            false
          else
            other = List.first(other_participants)
            other && (Social.blocked_by?(current_user.id, other.user_id) ||
                       Social.blocked_by?(other.user_id, current_user.id))
          end

        # Get participant public keys for conversation key creation
        participant_ids = Enum.map(conversation.participants, & &1.user_id)
        public_keys = Encryption.get_public_keys(participant_ids)

        participant_public_keys =
          Map.new(public_keys, fn {uid, key} ->
            {to_string(uid), Base.encode64(key.public_key_spki)}
          end)

        missing_keys = Enum.reject(participant_ids, &Map.has_key?(public_keys, &1))

        # Get current user's encrypted conversation key if it exists
        conversation_key = Chat.get_conversation_key(conversation_id, current_user.id)
        encrypted_key = if conversation_key, do: Base.encode64(conversation_key.encrypted_key)

        # key_mismatch is detected client-side for accuracy.
        # The server starts with false; ChatCrypto pushes "report_key_mismatch" if
        # it fails to decrypt the conversation key with the user's current private key.
        key_mismatch = false

        # If this user has a key mismatch (new device/browser), auto-request
        # re-encryption from other online participants
        if connected?(socket) && key_mismatch do
          Chat.broadcast_key_reencryption_request(conversation.id, current_user.id)
        end

        messages = Chat.list_messages(conversation_id, limit: @per_page)
        has_more = length(messages) == @per_page

        page_title =
          if conversation.is_group do
            conversation.title || gettext("Group Chat")
          else
            other = List.first(other_participants)
            gettext("Chat with %{name}", name: participant_name(other))
          end

        {:ok,
         socket
         |> assign(:locale, locale)
         |> assign(:conversation, conversation)
         |> assign(:other_participants, other_participants)
         |> assign(:participant_public_keys, participant_public_keys)
         |> assign(:encrypted_key, encrypted_key)
         |> assign(:messages, messages)
         |> assign(:has_more_messages, has_more)
         |> assign(:message_offset, 0)
         |> assign(:reply_to, nil)
         |> assign(:editing_message, nil)
         |> assign(:page_title, page_title)
         |> assign(:typing_users, [])
         |> assign(:is_blocked, is_blocked)
         |> assign(:missing_keys, missing_keys)
         |> assign(:key_mismatch, key_mismatch)
         |> assign(:online_user_ids, online_user_ids)
         |> push_event("scroll_to_bottom", %{})}
      else
        {:ok, push_navigate(socket, to: ~p"/messages")}
      end
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("send_encrypted_message", %{"ciphertext" => ct, "iv" => iv} = params, socket) do
    if socket.assigns.is_blocked || socket.assigns.missing_keys != [] do
      {:noreply, socket}
    else
      current_user = socket.assigns.current_scope.current_user
      conversation = socket.assigns.conversation
      reply_to = socket.assigns.reply_to
      reply_to_id = params["reply_to_message_id"] || (reply_to && reply_to.id)

      opts = if reply_to_id, do: [reply_to_message_id: reply_to_id], else: []

      case Chat.store_message(conversation.id, current_user.id, ct, iv, opts) do
        {:ok, _message} ->
          {:noreply,
           socket
           |> assign(:reply_to, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    end
  end

  @impl true
  def handle_event("register_public_key", %{"public_key" => public_key_b64}, socket) do
    current_user = socket.assigns.current_scope.current_user
    public_key_spki = Base.decode64!(public_key_b64)

    Encryption.store_public_key(current_user.id, public_key_spki)

    # After registering a new key, check if this user can decrypt the conversation key.
    # If a conversation key exists but was encrypted before this new key, they'll need
    # a re-encryption. We don't auto-detect here — the client will report if decryption fails.
    {:noreply, socket}
  end

  @impl true
  def handle_event("report_key_mismatch", _params, socket) do
    require Logger
    Logger.debug("[ChatRekey] Client reported key mismatch for user #{socket.assigns.current_scope.current_user.id}")
    {:noreply, assign(socket, :key_mismatch, true)}
  end

  @impl true
  def handle_event("set_typing", %{"typing" => is_typing}, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation_id = socket.assigns.conversation.id
    Chat.set_typing(current_user.id, conversation_id, is_typing)
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    trimmed = String.trim(content)

    if conversation && trimmed != "" do
      case Chat.store_plaintext_message(conversation.id, current_user.id, trimmed) do
        {:ok, _message} ->
          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("ensure_conversation_key", _params, socket) do
    if socket.assigns.missing_keys != [] do
      {:noreply,
       push_event(socket, "encryption_error", %{
         message: gettext("Some participants haven't set up encryption yet.")
       })}
    else
      conversation_id = socket.assigns.conversation.id
      current_user_id = socket.assigns.current_scope.current_user.id

      existing = Chat.get_conversation_key(conversation_id, current_user_id)

      if existing do
        {:noreply,
         push_event(socket, "conversation_key", %{
           encrypted_key: Base.encode64(existing.encrypted_key)
         })}
      else
        # Send participant public keys so client can create and encrypt the key
        {:noreply,
         push_event(socket, "create_conversation_key", %{
           participant_public_keys: socket.assigns.participant_public_keys
         })}
      end
    end
  end

  @impl true
  def handle_event("store_conversation_keys", %{"encrypted_keys" => encrypted_keys}, socket) do
    conversation_id = socket.assigns.conversation.id
    current_user_id = socket.assigns.current_scope.current_user.id

    # Only store if no keys exist yet (first sender wins)
    existing = Chat.list_conversation_keys(conversation_id)

    if existing == [] do
      for {user_id, key_b64} <- encrypted_keys do
        Chat.store_conversation_key(conversation_id, user_id, key_b64)
      end
    end

    # Reply with current user's key
    key = Chat.get_conversation_key(conversation_id, current_user_id)

    if key do
      {:noreply,
       push_event(socket, "conversation_key", %{
         encrypted_key: Base.encode64(key.encrypted_key)
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_plaintext_message", %{"content" => content}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    trimmed = String.trim(content)

    if trimmed != "" do
      reply_to = socket.assigns.reply_to
      opts = if reply_to, do: [reply_to_message_id: reply_to.id], else: []

      case Chat.store_plaintext_message(conversation.id, current_user.id, trimmed, opts) do
        {:ok, _message} ->
          {:noreply, assign(socket, :reply_to, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_voice_message", %{"audio_base64" => audio_b64, "mime_type" => mime_type, "duration" => duration}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    reply_to = socket.assigns.reply_to

    uploads_dir = Application.get_env(:medoru, :uploads_dir)

    # Determine extension from mime type
    ext =
      cond do
        String.contains?(mime_type, "webm") -> ".webm"
        String.contains?(mime_type, "ogg") -> ".ogg"
        String.contains?(mime_type, "mp4") -> ".m4a"
        true -> ".webm"
      end

    filename = "#{Ecto.UUID.generate()}#{ext}"
    dest_dir = Path.join(uploads_dir, "voice_messages")
    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, filename)

    try do
      File.write!(dest_path, Base.decode64!(audio_b64))

      voice_path = "/uploads/voice_messages/#{filename}"

      opts = [
        reply_to_message_id: reply_to && reply_to.id,
        attachment_path: voice_path,
        attachment_type: "voice",
        duration_seconds: duration
      ]

      case Chat.store_plaintext_message(conversation.id, current_user.id, "🎤 Voice message", opts) do
        {:ok, _message} ->
          {:noreply, assign(socket, :reply_to, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send voice message."))}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to process voice message."))}
    end
  end

  @impl true
  def handle_event("load_more_messages", _params, socket) do
    conversation = socket.assigns.conversation
    current_offset = socket.assigns.message_offset

    new_offset = current_offset + @per_page
    older_messages = Chat.list_messages(conversation.id, limit: @per_page, offset: new_offset)
    has_more = length(older_messages) == @per_page

    {:noreply,
     socket
     |> assign(:messages, socket.assigns.messages ++ older_messages)
     |> assign(:has_more_messages, has_more)
     |> assign(:message_offset, new_offset)}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, :reply_to, nil)}
  end

  @impl true
  def handle_event("set_reply", %{"id" => message_id}, socket) do
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :reply_to, message)}
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Chat.delete_message(message_id, current_user.id) do
      {:ok, _} ->
        {:noreply, socket}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You can only delete your own messages."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete message."))}
    end
  end

  @impl true
  def handle_event("archive_conversation", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    Chat.archive_conversation(conversation.id, current_user.id)

    {:noreply, push_navigate(socket, to: ~p"/messages")}
  end

  @impl true
  def handle_event("leave_conversation", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    if conversation.is_group do
      Chat.leave_conversation(conversation.id, current_user.id)
      {:noreply, push_navigate(socket, to: ~p"/messages")}
    else
      {:noreply, put_flash(socket, :error, gettext("You can only leave group conversations."))}
    end
  end

  @impl true
  def handle_event("start_edit", %{"id" => message_id}, socket) do
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    if message && Chat.can_edit_message?(message, socket.assigns.current_scope.current_user.id) do
      {:noreply,
       socket
       |> assign(:editing_message, message)
       |> push_event("start_edit", %{
         message_id: message.id,
         ciphertext: Base.encode64(message.ciphertext),
         iv: Base.encode64(message.iv)
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_message, nil)}
  end

  @impl true
  def handle_event("edit_message", %{"ciphertext" => ct, "iv" => iv, "message_id" => message_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Chat.edit_message(message_id, current_user.id, %{
           "ciphertext" => Base.decode64!(ct),
           "iv" => Base.decode64!(iv)
         }) do
      {:ok, _} ->
        {:noreply, assign(socket, :editing_message, nil)}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You can only edit your own messages."))}

      {:error, :edit_window_expired} ->
        {:noreply, put_flash(socket, :error, gettext("Message can only be edited within 15 minutes."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to edit message."))}
    end
  end

  @impl true
  def handle_event("request_key_reencryption", _params, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user

    Chat.broadcast_key_reencryption_request(conversation.id, current_user.id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_re_encrypted_key", %{"target_user_id" => target_id, "encrypted_key" => key_b64}, socket) do
    conversation = socket.assigns.conversation
    require Logger
    Logger.debug("[ChatRekey] Received submit_re_encrypted_key from user #{socket.assigns.current_scope.current_user.id} for target #{target_id}")

    case Chat.upsert_conversation_key(conversation.id, target_id, key_b64) do
      {:ok, _} ->
        Logger.debug("[ChatRekey] Stored re-encrypted key, broadcasting to conversation #{conversation.id}")
        Chat.broadcast_reencrypted_key(conversation.id, target_id, key_b64)
        {:noreply, socket}

      {:error, reason} ->
        Logger.warning("[ChatRekey] Failed to store re-encrypted key: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, gettext("Failed to store re-encrypted key."))}
    end
  end

  @impl true
  def handle_info({:request_key_reencryption, target_user_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    # Only ask other participants (not the target user) to re-encrypt
    if current_user.id != target_user_id do
      # Get the target user's new public key
      target_key = Encryption.get_public_key(target_user_id)

      if target_key do
        require Logger
        Logger.debug("[ChatRekey] Pushing re_encrypt_for_user to user #{current_user.id} for target #{target_user_id}")

        {:noreply,
         push_event(socket, "re_encrypt_for_user", %{
           target_user_id: target_user_id,
           public_key: Base.encode64(target_key.public_key_spki)
         })}
      else
        require Logger
        Logger.warning("[ChatRekey] No active public key found for target user #{target_user_id}")
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:reencrypted_key, target_user_id, encrypted_key_b64}, socket) do
    current_user = socket.assigns.current_scope.current_user

    # Only the target user should process this
    if current_user.id == target_user_id do
      {:noreply,
       socket
       |> assign(:key_mismatch, false)
       |> push_event("conversation_key", %{encrypted_key: encrypted_key_b64})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    if connected?(socket) do
      Chat.mark_read(current_user.id, message.conversation_id)
    end

    message = Medoru.Repo.preload(message, [:sender, :reply_to_message])

    socket =
      socket
      |> assign(:messages, socket.assigns.messages ++ [message])
      |> push_event("scroll_to_bottom", %{})

    # Only decrypt if this is an encrypted message (not a classroom chat)
    socket =
      if is_nil(conversation.classroom_id) && message.ciphertext do
        push_event(socket, "decrypt_message", %{
          id: message.id,
          ciphertext: Base.encode64(message.ciphertext),
          iv: Base.encode64(message.iv)
        })
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == message_id do
          %{msg | is_deleted: true}
        else
          msg
        end
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:message_edited, message}, socket) do
    message = Medoru.Repo.preload(message, [:sender, :reply_to_message])

    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == message.id do
          message
        else
          msg
        end
      end)

    socket =
      socket
      |> assign(:messages, messages)
      |> push_event("decrypt_message", %{
        id: message.id,
        ciphertext: Base.encode64(message.ciphertext),
        iv: Base.encode64(message.iv)
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing, user_id, is_typing}, socket) do
    current_user = socket.assigns.current_scope.current_user

    typing_users =
      if user_id != current_user.id do
        if is_typing do
          [user_id | socket.assigns.typing_users] |> Enum.uniq()
        else
          Enum.reject(socket.assigns.typing_users, &(&1 == user_id))
        end
      else
        socket.assigns.typing_users
      end

    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_info({:read_receipt, user_id, read_at}, socket) do
    conversation = socket.assigns.conversation

    updated_participants =
      Enum.map(conversation.participants, fn p ->
        if p.user_id == user_id do
          %{p | last_read_at: read_at}
        else
          p
        end
      end)

    updated_conversation = %{conversation | participants: updated_participants}

    {:noreply, assign(socket, :conversation, updated_conversation)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online_user_ids = get_online_user_ids(socket.assigns.conversation.id)
    {:noreply, assign(socket, :online_user_ids, online_user_ids)}
  end

  # Presence helpers
  defp get_online_user_ids(conversation_id) do
    Presence.list("chat_presence:#{conversation_id}")
    |> Enum.map(fn {user_id, _} -> user_id end)
  end

  def user_online?(user_id, online_user_ids) do
    user_id in online_user_ids
  end

  def can_edit_message?(message, current_user_id) do
    Chat.can_edit_message?(message, current_user_id)
  end

  def can_delete_message?(message, current_user_id) do
    Chat.can_delete_message?(message, current_user_id)
  end

  @doc """
  Checks if a message consists only of emojis (for large rendering without bubble).
  """
  def emoji_only?(nil), do: false
  def emoji_only?(text) do
    trimmed = String.trim(text)
    trimmed != "" and String.replace(trimmed, ~r/[\s\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F900}-\x{1F9FF}\x{1F004}\x{1F0CF}\x{1F170}-\x{1F251}\x{238C}\x{2B50}\x{2B55}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2B05}-\x{2B07}\x{3030}\x{303D}\x{3297}\x{3299}\x{23F0}-\x{23F3}\x{23E9}-\x{23EF}\x{1F18E}\x{00A9}\x{00AE}\x{FE0F}\x{200D}\x{1F3FB}-\x{1F3FF}]/u, "") == ""
  end

  @doc """
  Formats audio duration as M:SS.
  """
  def format_audio_duration(nil), do: "0:00"
  def format_audio_duration(seconds) when seconds < 60, do: "0:#{String.pad_leading("#{seconds}", 2, "0")}"
  def format_audio_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}:#{String.pad_leading("#{s}", 2, "0")}"
  end

  @doc """
  Checks if a message sent by the current user has been read by other participants.
  """
  def message_read_by_others?(message, conversation, current_user_id) do
    other_participants = Enum.reject(conversation.participants, &(&1.user_id == current_user_id))

    Enum.any?(other_participants, fn participant ->
      participant.last_read_at && DateTime.compare(participant.last_read_at, message.inserted_at) != :lt
    end)
  end

  # Helpers
  def participant_name(participant) do
    user = participant && participant.user

    if user do
      (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")
    else
      gettext("Unknown")
    end
  end

  def participant_avatar(participant) do
    user = participant && participant.user

    if user do
      (user.profile && user.profile.avatar) || user.avatar_url
    end
  end

  def message_ciphertext_b64(message) do
    Base.encode64(message.ciphertext)
  end

  def message_iv_b64(%{iv: nil}), do: ""
  def message_iv_b64(message), do: Base.encode64(message.iv)

  def format_message_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  def format_message_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y")
  end

  def same_day?(%DateTime{} = a, %DateTime{} = b) do
    DateTime.to_date(a) == DateTime.to_date(b)
  end

  def show_date_separator?(messages, index) do
    if index == 0 do
      true
    else
      current = Enum.at(messages, index)
      prev = Enum.at(messages, index - 1)

      current && prev && not same_day?(current.inserted_at, prev.inserted_at)
    end
  end

  def sender_name(message, current_user_id) do
    if message.sender_id == current_user_id do
      gettext("You")
    else
      participant_name(%{user: message.sender})
    end
  end
end
