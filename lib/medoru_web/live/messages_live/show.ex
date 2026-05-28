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
  alias Medoru.Notifications
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
          {:ok, _} =
            Medoru.Notifications.mark_chat_notifications_as_read(
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

            other &&
              (Social.blocked_by?(current_user.id, other.user_id) ||
                 Social.blocked_by?(other.user_id, current_user.id))
          end

        # Get participant public keys for conversation key creation.
        # get_public_keys/1 now returns %{user_id => [keys]} (multi-device support).
        participant_ids = Enum.map(conversation.participants, & &1.user_id)
        public_keys = Encryption.get_public_keys(participant_ids)

        # Backward-compat: single most-recent key per user (old clients)
        participant_public_keys =
          Map.new(public_keys, fn {uid, keys} ->
            most_recent = List.first(keys)
            {to_string(uid), Base.encode64(most_recent.public_key_spki)}
          end)

        # Multi-key format: all active keys per user (new clients)
        participant_public_keys_v2 =
          Map.new(public_keys, fn {uid, keys} ->
            {to_string(uid), Enum.map(keys, &Base.encode64(&1.public_key_spki))}
          end)

        missing_keys = Enum.reject(participant_ids, &Map.has_key?(public_keys, &1))

        # Get current user's encrypted conversation keys (multi-device support).
        conversation_keys = Chat.get_conversation_keys(conversation_id, current_user.id)

        # Backward-compat: single string for old clients
        encrypted_key =
          case conversation_keys do
            [first | _] -> Base.encode64(first.encrypted_key)
            _ -> nil
          end

        # Multi-key format: array with fingerprints for new clients
        encrypted_keys_v2 =
          Enum.map(conversation_keys, fn ck ->
            %{
              fingerprint: ck.key_fingerprint || "legacy",
              key: Base.encode64(ck.encrypted_key)
            }
          end)

        # key_mismatch is detected client-side for accuracy.
        key_mismatch = false
        last_registered_key = nil

        # Chat keyboard shortcut preference
        chat_enter_sends =
          current_user.profile && current_user.profile.chat_enter_sends != false

        # If this user has no conversation key but others do, request re-encryption.
        if connected?(socket) && conversation_keys == [] && missing_keys == [] do
          other_keys = Chat.list_conversation_keys(conversation_id)

          if other_keys != [] do
            Chat.broadcast_key_reencryption_request(conversation.id, current_user.id)
          end
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
         |> assign(:participant_public_keys_v2, participant_public_keys_v2)
         |> assign(:encrypted_key, encrypted_key)
         |> assign(:encrypted_keys_v2, encrypted_keys_v2)
         |> assign(:messages, messages)
         |> assign(:has_more_messages, has_more)
         |> assign(:message_offset, 0)
         |> assign(:reply_to, nil)
         |> assign(:preview_message, nil)
         |> assign(:editing_message, nil)
         |> assign(:page_title, page_title)
         |> assign(:typing_users, [])
         |> assign(:is_blocked, is_blocked)
         |> assign(:missing_keys, missing_keys)
         |> assign(:key_mismatch, key_mismatch)
         |> assign(:last_registered_key, last_registered_key)
         |> assign(:chat_enter_sends, chat_enter_sends)
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
           |> assign(:reply_to, nil)
           |> assign(:preview_message, nil)}

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

    conversation = socket.assigns.conversation

    # Update missing_keys since this user now has a registered key
    missing_keys = Enum.reject(socket.assigns.missing_keys, &(&1 == current_user.id))

    # If this user was previously missing from the conversation key,
    # ask other online participants to re-encrypt for them.
    if connected?(socket) do
      Chat.broadcast_key_reencryption_request(conversation.id, current_user.id)

      # Notify other participants that this user now has a key so they can update UI
      Phoenix.PubSub.broadcast(
        Medoru.PubSub,
        "chat:#{conversation.id}",
        {:participant_key_registered, current_user.id}
      )
    end

    {:noreply,
     socket
     |> assign(:missing_keys, missing_keys)
     |> assign(:last_registered_key, public_key_b64)}
  end

  @impl true
  def handle_event("report_key_mismatch", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    require Logger
    Logger.debug("[ChatRekey] Client reported key mismatch for user #{current_user.id}")

    # Immediately broadcast a re-encryption request to any online participants.
    # The client will also retry periodically until someone responds.
    if connected?(socket) do
      preferred_key = socket.assigns.last_registered_key
      Chat.broadcast_key_reencryption_request(conversation.id, current_user.id, preferred_key)
    end

    socket = assign(socket, :key_mismatch, true)

    # Check if anyone else is actually online to provide the key
    other_online =
      Presence.list("chat_presence:#{conversation.id}")
      |> Enum.reject(fn {uid, _} -> uid == current_user.id end)

    socket =
      if other_online == [] do
        put_flash(
          socket,
          :info,
          gettext(
            "No one else is online right now. We'll keep trying when someone comes online, or you can reset encryption below."
          )
        )
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("acknowledge_conversation_key", _params, socket) do
    {:noreply, assign(socket, :key_mismatch, false)}
  end

  @impl true
  def handle_event("send_chat_invitation", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation
    missing_keys = socket.assigns.missing_keys

    sender_name =
      (current_user.profile && current_user.profile.display_name) ||
        current_user.name || gettext("Someone")

    for user_id <- missing_keys do
      Notifications.notify_chat_invitation(user_id, sender_name, conversation.id)

      Notifications.send_push_notification(
        user_id,
        "💬 #{sender_name} wants to chat",
        "Tap to open the conversation and set up encryption.",
        %{conversation_id: conversation.id}
      )
    end

    {:noreply,
     socket
     |> assign(:invitation_sent, true)
     |> put_flash(
       :info,
       gettext("Invitation sent. You'll be able to chat once they set up encryption.")
     )}
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
          {:noreply, assign(socket, :preview_message, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("ensure_conversation_key", _params, socket) do
    conversation_id = socket.assigns.conversation.id
    current_user_id = socket.assigns.current_scope.current_user.id

    existing_keys = Chat.get_conversation_keys(conversation_id, current_user_id)

    if existing_keys != [] do
      # Backward-compat: send single string
      encrypted_key = Base.encode64(hd(existing_keys).encrypted_key)

      # Multi-key: send array with fingerprints
      encrypted_keys_v2 =
        Enum.map(existing_keys, fn ck ->
          %{
            fingerprint: ck.key_fingerprint || "legacy",
            key: Base.encode64(ck.encrypted_key)
          }
        end)

      {:noreply,
       push_event(socket, "conversation_key", %{
         encrypted_key: encrypted_key,
         encrypted_keys_v2: encrypted_keys_v2
       })}
    else
      other_keys = Chat.list_conversation_keys(conversation_id)

      cond do
        other_keys != [] ->
          # A shared key exists for other participants but not yet for this user.
          # Re-encryption is in progress (triggered by register_public_key or mount).
          # The client will receive the key via the conversation_key event shortly.
          {:noreply, socket}

        socket.assigns.missing_keys != [] ->
          {:noreply,
           push_event(socket, "encryption_error", %{
             message: gettext("Some participants haven't set up encryption yet.")
           })}

        true ->
          # No keys exist at all — this user is the first to create the shared key.
          # Send both formats so old and new clients can both create keys.
          {:noreply,
           push_event(socket, "create_conversation_key", %{
             participant_public_keys: socket.assigns.participant_public_keys,
             participant_public_keys_v2: socket.assigns.participant_public_keys_v2
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
      for {user_id, entries} <- encrypted_keys do
        cond do
          is_list(entries) and entries != [] and is_map(hd(entries)) ->
            # New multi-key format: [%{"fingerprint" => fp, "encrypted_key" => b64}, ...]
            for %{"fingerprint" => fp, "encrypted_key" => key_b64} <- entries do
              Chat.store_conversation_key(conversation_id, user_id, key_b64, fp)
            end

          is_binary(entries) ->
            # Legacy single-key format: "base64_key"
            Chat.store_conversation_key(conversation_id, user_id, entries)

          true ->
            :ok
        end
      end
    end

    # Reply with current user's key in both formats
    keys = Chat.get_conversation_keys(conversation_id, current_user_id)

    if keys != [] do
      encrypted_key = Base.encode64(hd(keys).encrypted_key)

      encrypted_keys_v2 =
        Enum.map(keys, fn ck ->
          %{
            fingerprint: ck.key_fingerprint || "legacy",
            key: Base.encode64(ck.encrypted_key)
          }
        end)

      {:noreply,
       push_event(socket, "conversation_key", %{
         encrypted_key: encrypted_key,
         encrypted_keys_v2: encrypted_keys_v2
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
          {:noreply,
           socket
           |> assign(:reply_to, nil)
           |> assign(:preview_message, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send message."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "send_voice_message",
        %{"audio_base64" => audio_b64, "mime_type" => mime_type, "duration" => duration},
        socket
      ) do
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
          {:noreply,
           socket
           |> assign(:reply_to, nil)
           |> assign(:preview_message, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to send voice message."))}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, gettext("Failed to process voice message."))}
    end
  end

  @impl true
  def handle_event(
        "send_image_message",
        %{"image_base64" => img_b64, "mime_type" => mime_type} = params,
        socket
      ) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_scope.current_user
    reply_to = socket.assigns.reply_to

    # Validate MIME type
    valid_image_type =
      String.starts_with?(mime_type, "image/jpeg") or
        String.starts_with?(mime_type, "image/png") or
        String.starts_with?(mime_type, "image/gif") or
        String.starts_with?(mime_type, "image/webp")

    if not valid_image_type do
      {:noreply,
       put_flash(
         socket,
         :error,
         gettext("Invalid image format. Only JPEG, PNG, GIF, and WebP are supported.")
       )}
    else
      uploads_dir = Application.get_env(:medoru, :uploads_dir)

      ext =
        cond do
          String.contains?(mime_type, "png") -> ".png"
          String.contains?(mime_type, "gif") -> ".gif"
          String.contains?(mime_type, "webp") -> ".webp"
          true -> ".jpg"
        end

      filename = "#{Ecto.UUID.generate()}#{ext}"
      dest_dir = Path.join(uploads_dir, "chat_images")
      File.mkdir_p!(dest_dir)
      dest_path = Path.join(dest_dir, filename)

      try do
        decoded = Base.decode64!(img_b64)

        # 5MB limit
        if byte_size(decoded) > 5_000_000 do
          {:noreply,
           put_flash(socket, :error, gettext("Image is too large. Maximum size is 5MB."))}
        else
          File.write!(dest_path, decoded)
          image_path = "/uploads/chat_images/#{filename}"

          opts = [
            reply_to_message_id: reply_to && reply_to.id,
            attachment_path: image_path,
            attachment_type: "image"
          ]

          result =
            if conversation.classroom_id do
              Chat.store_plaintext_message(conversation.id, current_user.id, "📷 Image", opts)
            else
              ct = params["ciphertext"]
              iv = params["iv"]
              Chat.store_message(conversation.id, current_user.id, ct, iv, opts)
            end

          case result do
            {:ok, _message} ->
              {:noreply,
               socket
               |> assign(:reply_to, nil)
               |> assign(:preview_message, nil)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Failed to send image."))}
          end
        end
      rescue
        _ ->
          {:noreply, put_flash(socket, :error, gettext("Failed to process image."))}
      end
    end
  end

  @impl true
  def handle_event("load_more_messages", _params, socket) do
    conversation = socket.assigns.conversation
    current_offset = socket.assigns.message_offset

    new_offset = current_offset + @per_page
    older_messages = Chat.list_messages(conversation.id, limit: @per_page, offset: new_offset)
    has_more = length(older_messages) == @per_page

    # Prepend older messages so the list stays in chronological order
    # (oldest first, newest last). list_messages returns each batch in
    # oldest-to-newest order, so older_messages belongs before messages.
    {:noreply,
     socket
     |> assign(:messages, older_messages ++ socket.assigns.messages)
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
  def handle_event("preview_message", %{"id" => message_id}, socket) do
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :preview_message, message)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :preview_message, nil)}
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
  def handle_event(
        "edit_message",
        %{"ciphertext" => ct, "iv" => iv, "message_id" => message_id},
        socket
      ) do
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
        {:noreply,
         put_flash(socket, :error, gettext("Message can only be edited within 15 minutes."))}

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
  def handle_event("reset_conversation_keys", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    require Logger

    Logger.info(
      "[ChatRekey] User #{current_user.id} reset conversation keys for #{conversation.id}"
    )

    Chat.delete_conversation_keys(conversation.id)
    Chat.broadcast_encryption_reset(conversation.id)

    {:noreply,
     socket
     |> assign(:key_mismatch, false)
     |> assign(:encrypted_key, nil)
     |> put_flash(
       :warning,
       gettext(
         "Encryption has been reset. Old messages cannot be decrypted, but you can now send new messages."
       )
     )
     |> push_event("encryption_reset", %{})}
  end

  @impl true
  def handle_event("submit_re_encrypted_key", params, socket) do
    conversation = socket.assigns.conversation
    target_id = params["target_user_id"]
    require Logger

    Logger.debug(
      "[ChatRekey] Received submit_re_encrypted_key from user #{socket.assigns.current_scope.current_user.id} for target #{target_id}"
    )

    # Handle both legacy single-key and new multi-key formats
    stored =
      cond do
        encrypted_keys = params["encrypted_keys"] ->
          # New multi-key format: [%{"fingerprint" => fp, "encrypted_key" => b64}, ...]
          for %{"fingerprint" => fp, "encrypted_key" => key_b64} <- encrypted_keys do
            Chat.upsert_conversation_key(conversation.id, target_id, key_b64, fp)
          end

        key_b64 = params["encrypted_key"] ->
          # Legacy single-key format
          [Chat.upsert_conversation_key(conversation.id, target_id, key_b64)]

        true ->
          []
      end

    if Enum.any?(stored, &match?({:ok, _}, &1)) do
      Logger.debug(
        "[ChatRekey] Stored re-encrypted key(s), broadcasting to conversation #{conversation.id}"
      )

      # Broadcast ALL keys for the target user so every device gets its copy
      target_keys = Chat.get_conversation_keys(conversation.id, target_id)

      encrypted_keys_v2 =
        Enum.map(target_keys, fn ck ->
          %{
            fingerprint: ck.key_fingerprint || "legacy",
            key: Base.encode64(ck.encrypted_key)
          }
        end)

      encrypted_key =
        case target_keys do
          [first | _] -> Base.encode64(first.encrypted_key)
          _ -> nil
        end

      Phoenix.PubSub.broadcast(
        Medoru.PubSub,
        "chat:#{conversation.id}",
        {:reencrypted_key, target_id, encrypted_key, encrypted_keys_v2}
      )

      {:noreply, socket}
    else
      Logger.warning("[ChatRekey] Failed to store re-encrypted key(s)")
      {:noreply, put_flash(socket, :error, gettext("Failed to store re-encrypted key."))}
    end
  end

  @impl true
  def handle_info({:participant_key_registered, user_id}, socket) do
    missing_keys = Enum.reject(socket.assigns.missing_keys, &(&1 == user_id))

    # Refresh public keys for this user in case they added a new device key
    refreshed_keys = Encryption.get_public_keys_for_user(user_id)

    participant_public_keys =
      Map.update(socket.assigns.participant_public_keys, to_string(user_id), nil, fn _ ->
        case refreshed_keys do
          [first | _] -> Base.encode64(first.public_key_spki)
          _ -> nil
        end
      end)

    participant_public_keys_v2 =
      Map.update(socket.assigns.participant_public_keys_v2, to_string(user_id), [], fn _ ->
        Enum.map(refreshed_keys, &Base.encode64(&1.public_key_spki))
      end)

    {:noreply,
     socket
     |> assign(:missing_keys, missing_keys)
     |> assign(:participant_public_keys, participant_public_keys)
     |> assign(:participant_public_keys_v2, participant_public_keys_v2)}
  end

  @impl true
  def handle_info({:request_key_reencryption, target_user_id, preferred_key_b64}, socket) do
    current_user = socket.assigns.current_scope.current_user

    # Ask ALL online participants (including the target user's other devices)
    # to re-encrypt. The client-side ChatCrypto hook will silently bail out
    # if it doesn't have the conversation key cached, so this is safe.
    # This enables same-user multi-device recovery: Device 1 can re-encrypt
    # for Device 2 when both are online.
    target_keys = Encryption.get_public_keys_for_user(target_user_id)

    if target_keys != [] do
      require Logger

      Logger.debug(
        "[ChatRekey] Pushing re_encrypt_for_user to user #{current_user.id} for target #{target_user_id}"
      )

      public_keys = Enum.map(target_keys, &Base.encode64(&1.public_key_spki))

      # Backward compat: old clients only re-encrypt for one key.
      # Use the preferred key (the one the target client just registered)
      # instead of blindly picking the most recent key, which might belong
      # to a different device.
      backward_compat_key =
        if preferred_key_b64 && preferred_key_b64 in public_keys do
          preferred_key_b64
        else
          List.first(public_keys)
        end

      {:noreply,
       push_event(socket, "re_encrypt_for_user", %{
         target_user_id: target_user_id,
         public_keys: public_keys,
         public_key: backward_compat_key
       })}
    else
      require Logger
      Logger.warning("[ChatRekey] No active public key found for target user #{target_user_id}")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {:reencrypted_key, target_user_id, encrypted_key_b64, encrypted_keys_v2},
        socket
      ) do
    current_user = socket.assigns.current_scope.current_user

    # Only the target user should process this
    if current_user.id == target_user_id do
      # Do NOT set key_mismatch = false here — the banner would hide before
      # the client confirms it can actually decrypt. The client sends
      # "acknowledge_conversation_key" after successful decryption.
      #
      # Send both formats: old clients use encrypted_key string,
      # new clients use encrypted_keys_v2 array.
      {:noreply,
       push_event(socket, "conversation_key", %{
         encrypted_key: encrypted_key_b64,
         encrypted_keys_v2: encrypted_keys_v2
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:encryption_reset, _conversation_id}, socket) do
    {:noreply, push_event(socket, "encryption_reset", %{})}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    if connected?(socket) do
      Chat.mark_read(current_user.id, message.conversation_id)

      # Safety net: clear any chat notifications that may have been created
      # due to a race condition while the user is actively in the chat.
      {:ok, _} =
        Notifications.mark_chat_notifications_as_read(
          current_user.id,
          message.conversation_id
        )
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

    trimmed != "" and
      String.replace(
        trimmed,
        ~r/[\s\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F900}-\x{1F9FF}\x{1F004}\x{1F0CF}\x{1F170}-\x{1F251}\x{238C}\x{2B50}\x{2B55}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2B05}-\x{2B07}\x{3030}\x{303D}\x{3297}\x{3299}\x{23F0}-\x{23F3}\x{23E9}-\x{23EF}\x{1F18E}\x{00A9}\x{00AE}\x{FE0F}\x{200D}\x{1F3FB}-\x{1F3FF}]/u,
        ""
      ) == ""
  end

  @doc """
  Formats audio duration as M:SS.
  """
  def format_audio_duration(nil), do: "0:00"

  def format_audio_duration(seconds) when seconds < 60,
    do: "0:#{String.pad_leading("#{seconds}", 2, "0")}"

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
      participant.last_read_at &&
        DateTime.compare(participant.last_read_at, message.inserted_at) != :lt
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

  def message_ciphertext_b64(%{ciphertext: nil}), do: ""

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

  attr :message, :map, required: true
  attr :current_user_id, :string, required: true
  attr :conversation, :map, required: true

  def message_preview_panel(assigns) do
    ~H"""
    <div class="flex items-center justify-between px-4 py-3 border-b border-base-300 shrink-0">
      <h3 class="font-medium text-sm text-base-content">{gettext("Message")}</h3>
      <button
        type="button"
        phx-click="close_preview"
        class="p-1 text-base-content/40 hover:text-base-content transition-colors"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    <div class="preview-body flex-1 overflow-y-auto p-4 flex flex-col gap-4">
      <div class="flex items-start gap-3">
        <% sender_avatar =
          (@message.sender.profile && @message.sender.profile.avatar) || @message.sender.avatar_url %>
        <%= if sender_avatar do %>
          <img
            src={sender_avatar}
            alt=""
            class="w-10 h-10 rounded-full object-cover ring-2 ring-base-200 shrink-0"
          />
        <% else %>
          <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center ring-2 ring-base-200 shrink-0">
            <.icon name="hero-user" class="w-5 h-5 text-primary/50" />
          </div>
        <% end %>
        <div class="min-w-0">
          <p class="font-medium text-sm text-base-content">
            {sender_name(@message, @current_user_id)}
          </p>
          <p class="text-xs text-base-content/50">
            {format_message_time(@message.inserted_at)}
          </p>
        </div>
      </div>
      <div class="bg-base-200/50 rounded-2xl p-4">
        <%= cond do %>
          <% @message.is_deleted -> %>
            <p class="text-sm italic text-base-content/60">{gettext("This message was deleted")}</p>
          <% @message.attachment_type == "image" && @message.attachment_path -> %>
            <img
              src={@message.attachment_path}
              alt={gettext("Image")}
              class="max-w-full rounded-lg"
              loading="lazy"
            />
          <% @message.attachment_type == "voice" && @message.attachment_path -> %>
            <audio controls class="w-full">
              <source src={@message.attachment_path} />
            </audio>
          <% @message.ciphertext -> %>
            <p
              class="text-[15px] leading-snug whitespace-pre-wrap break-words text-base-content"
              data-msg-id={@message.id}
              data-encrypted="true"
              data-ciphertext={message_ciphertext_b64(@message)}
              data-iv={message_iv_b64(@message)}
            >
              [...]
            </p>
          <% true -> %>
            <p class="text-[15px] leading-snug whitespace-pre-wrap break-words text-base-content">
              {@message.content}
            </p>
        <% end %>
      </div>
    </div>
    """
  end

  def sender_name(message, current_user_id) do
    if message.sender_id == current_user_id do
      gettext("You")
    else
      participant_name(%{user: message.sender})
    end
  end
end
