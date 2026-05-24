defmodule MedoruWeb.MessagesLive.Index do
  @moduledoc """
  LiveView for the chat list (conversations).
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Social

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    current_user = socket.assigns.current_scope.current_user

    if current_user do
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

      {:ok,
       socket
       |> assign(:locale, locale)
       |> assign(:conversations, conversations)
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
end
