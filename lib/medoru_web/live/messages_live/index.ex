defmodule MedoruWeb.MessagesLive.Index do
  @moduledoc """
  LiveView for the chat list (conversations).
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Social
  alias MedoruWeb.Presence

  @per_page 30

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

      {conversations, has_more} = fetch_conversations(current_user.id, 0, @per_page)
      online_user_ids = build_online_user_ids(conversations, current_user.id)

      {:ok,
       socket
       |> assign(:locale, locale)
       |> assign(:conversations, conversations)
       |> assign(:online_user_ids, online_user_ids)
       |> assign(:page, 0)
       |> assign(:has_more, has_more)
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
    {conversations, has_more} = fetch_conversations(current_user.id, 0, @per_page)
    online_user_ids = build_online_user_ids(conversations, current_user.id)

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:online_user_ids, online_user_ids)
     |> assign(:page, 0)
     |> assign(:has_more, has_more)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    next_page = socket.assigns.page + 1

    {new_conversations, has_more} = fetch_conversations(current_user.id, next_page, @per_page)
    online_user_ids = build_online_user_ids(new_conversations, current_user.id)

    conversations = socket.assigns.conversations ++ new_conversations

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:online_user_ids, Enum.uniq(socket.assigns.online_user_ids ++ online_user_ids))
     |> assign(:page, next_page)
     |> assign(:has_more, has_more)}
  end

  # Helpers for template
  def conversation_name(conversation, current_user_id) do
    if conversation.is_group do
      conversation.title || gettext("Group Chat")
    else
      other = Chat.get_other_participant(conversation, current_user_id)
      participant_name(other, current_user_id)
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

  def participant_name(participant, viewer_id) do
    user = participant && participant.user

    if user do
      Social.display_name_for_viewer(user, viewer_id)
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

  def last_message_preview(conversation) do
    # Classroom chats are plaintext; other chats are encrypted server-side.
    if conversation.classroom_id && conversation.last_message do
      text =
        conversation.last_message.content
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
        |> String.slice(0, 15)

      if text == "" do
        gettext("No preview")
      else
        if String.length(conversation.last_message.content) > 15, do: text <> "…", else: text
      end
    else
      gettext("Encrypted message")
    end
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
      Calendar.strftime(dt, "%d.%m.%y %H:%M")
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

  defp fetch_conversations(user_id, page, per_page) do
    # Fetch one extra to determine if there are more pages
    limit = per_page + 1
    offset = page * per_page

    conversations =
      Chat.list_conversations(user_id, limit: limit, offset: offset)
      |> Enum.reject(fn conv ->
        if conv.is_group do
          false
        else
          other = Chat.get_other_participant(conv, user_id)
          other && Social.is_blocked?(user_id, other.user_id) == :blocked
        end
      end)

    has_more = length(conversations) > per_page
    conversations = Enum.take(conversations, per_page)

    {conversations, has_more}
  end
end
