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
        end

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
         |> assign(:page_title, page_title)
         |> assign(:typing_users, [])
         |> assign(:is_blocked, is_blocked)
         |> assign(:missing_keys, missing_keys)
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

    # If this user didn't have a key before, they might need the conversation key
    # re-encrypted for them. For now, we just acknowledge.
    {:noreply, socket}
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
  def handle_info({:read_receipt, _user_id, _read_at}, socket) do
    {:noreply, socket}
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
