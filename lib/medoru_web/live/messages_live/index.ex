defmodule MedoruWeb.MessagesLive.Index do
  @moduledoc """
  LiveView for the chat list (conversations).
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Social
  alias MedoruWeb.Presence

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    current_user = socket.assigns.current_scope.current_user

    if current_user do
      if connected?(socket) do
        Presence.track(self(), "user_online:#{current_user.id}", "online", %{
          online_at: System.system_time(:second)
        })
      end

      conversations =
        Chat.list_conversations(current_user.id, limit: 50)
        |> Enum.reject(fn conv ->
          # For 1:1, filter blocked users. Groups are not filtered.
          if conv.is_group do
            false
          else
            other = Chat.get_other_participant(conv, current_user.id)
            other && Social.is_blocked?(current_user.id, other.user_id) == :blocked
          end
        end)

      online_user_ids = build_online_user_ids(conversations, current_user.id)

      {:ok,
       socket
       |> assign(:locale, locale)
       |> assign(:conversations, conversations)
       |> assign(:online_user_ids, online_user_ids)
       |> assign(:page_title, gettext("Messages"))}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle "start conversation with user" from user profile
    case params["user"] do
      nil ->
        {:noreply, socket}

      user_id ->
        current_user = socket.assigns.current_scope.current_user

        # Check if messaging is allowed
        if Social.can_message?(current_user.id, user_id) do
          case Chat.find_or_create_conversation(current_user.id, user_id) do
            {:ok, conversation} ->
              {:noreply, push_navigate(socket, to: ~p"/messages/#{conversation.id}")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Could not start conversation."))}
          end
        else
          {:noreply, put_flash(socket, :error, gettext("You cannot message this user."))}
        end
    end
  end

  @impl true
  def handle_event("archive_conversation", %{"id" => conversation_id}, socket) do
    current_user = socket.assigns.current_scope.current_user
    Chat.archive_conversation(conversation_id, current_user.id)

    # Refresh the list
    conversations =
      Chat.list_conversations(current_user.id, limit: 50)
      |> Enum.reject(fn conv ->
        if conv.is_group do
          false
        else
          other = Chat.get_other_participant(conv, current_user.id)
          other && Social.is_blocked?(current_user.id, other.user_id) == :blocked
        end
      end)

    online_user_ids = build_online_user_ids(conversations, current_user.id)

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:online_user_ids, online_user_ids)}
  end

  # Helpers for template
  def conversation_name(conversation, current_user_id) do
    if conversation.is_group do
      conversation.title || gettext("Group Chat")
    else
      other = Chat.get_other_participant(conversation, current_user_id)
      participant_name(other)
    end
  end

  def conversation_avatar(conversation, current_user_id) do
    if conversation.is_group do
      nil
    else
      other = Chat.get_other_participant(conversation, current_user_id)
      participant_avatar(other)
    end
  end

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

  def last_message_preview(_conversation) do
    # Messages are encrypted; server cannot show a preview
    gettext("Encrypted message")
  end

  def last_message_time(conversation) do
    case conversation.last_message do
      nil -> ""
      message -> format_time(message.inserted_at)
    end
  end

  def unread_count(conversation, current_user_id) do
    Chat.count_unread_messages(conversation.id, current_user_id)
  end

  defp format_time(%DateTime{} = dt) do
    now = DateTime.utc_now()

    if DateTime.to_date(dt) == DateTime.to_date(now) do
      Calendar.strftime(dt, "%H:%M")
    else
      Calendar.strftime(dt, "%b %d")
    end
  end

  defp build_online_user_ids(conversations, current_user_id) do
    conversations
    |> Enum.flat_map(fn conv ->
      if conv.is_group do
        []
      else
        other = Chat.get_other_participant(conv, current_user_id)
        if other, do: [other.user_id], else: []
      end
    end)
    |> Enum.uniq()
    |> Enum.filter(fn user_id ->
      Presence.list("user_online:#{user_id}") != %{}
    end)
  end

  def user_online?(user_id, online_user_ids) do
    user_id in online_user_ids
  end
end
