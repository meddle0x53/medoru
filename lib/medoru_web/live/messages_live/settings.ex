defmodule MedoruWeb.MessagesLive.Settings do
  @moduledoc """
  LiveView for changing the shared theme of a 1-1 or group chat.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Classrooms.Classroom
  alias Medoru.Social

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = Chat.get_conversation(current_user.id, conversation_id)

    cond do
      is_nil(conversation) ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Conversation not found."))
         |> push_navigate(to: ~p"/messages")}

      conversation.classroom_id != nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Classroom chats use the classroom theme."))
         |> push_navigate(to: ~p"/messages/#{conversation.id}")}

      blocked?(conversation, current_user.id) ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Conversation not found."))
         |> push_navigate(to: ~p"/messages")}

      true ->
        page_title =
          if conversation.is_group do
            conversation.title || gettext("Group Chat")
          else
            other = List.first(Chat.get_other_participants(conversation, current_user.id))
            gettext("Chat with %{name}", name: participant_name(other, current_user.id))
          end

        {:ok,
         socket
         |> assign(:conversation, conversation)
         |> assign(:page_title, page_title)
         |> assign(:themes, Classroom.allowed_themes())
         |> assign(:current_theme, conversation.theme)}
    end
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    current_user = socket.assigns.current_scope.current_user
    conversation = socket.assigns.conversation

    case Chat.update_conversation_theme(current_user.id, conversation.id, theme) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Theme updated"))
         |> push_navigate(to: ~p"/messages/#{updated.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        error =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
            Gettext.dgettext(MedoruWeb.Gettext, "errors", msg, opts)
          end)
          |> Enum.map(fn {k, v} -> "#{k} #{Enum.join(v, ", ")}" end)
          |> Enum.join("; ")

        {:noreply,
         socket
         |> put_flash(:error, gettext("Could not update theme: %{error}", error: error))}

      {:error, reason} ->
        message =
          case reason do
            :not_found -> gettext("Conversation not found.")
            :classroom -> gettext("Classroom chats use the classroom theme.")
            _ -> gettext("Could not update theme.")
          end

        {:noreply, socket |> put_flash(:error, message)}
    end
  end

  defp blocked?(conversation, current_user_id) do
    if conversation.is_group do
      false
    else
      other = List.first(Chat.get_other_participants(conversation, current_user_id))

      other &&
        (Social.blocked_by?(current_user_id, other.user_id) ||
           Social.blocked_by?(other.user_id, current_user_id))
    end
  end

  defp participant_name(participant, viewer_id) do
    user = participant && participant.user

    if user do
      Social.display_name_for_viewer(user, viewer_id)
    else
      gettext("Unknown")
    end
  end
end
