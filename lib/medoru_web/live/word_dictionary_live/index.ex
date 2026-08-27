defmodule MedoruWeb.WordDictionaryLive.Index do
  @moduledoc """
  Main personal dictionary page accessible from /words/dictionary.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Dictionaries

  embed_templates "index.html"

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.current_user
    main_dictionary = Dictionaries.get_or_create_main_dictionary(current_user.id)

    {:ok,
     socket
     |> assign(:page_title, gettext("My Dictionary"))
     |> assign(:main_dictionary, main_dictionary)
     |> assign(:editing_entry, nil)
     |> assign(:search_query, "")
     |> assign(:selected_category, nil)
     |> assign(:send_to_chat_entry, nil)
     |> assign(:conversations, [])
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_category", %{"category" => category}, socket) do
    category = if category in ["", nil], do: nil, else: category

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> refresh_entries()}
  end

  @impl true
  def handle_event("create_entry", %{"entry" => entry_params}, socket) do
    dictionary = socket.assigns.main_dictionary

    case Dictionaries.create_entry(dictionary, entry_params) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> assign(:editing_entry, nil)
         |> put_flash(:info, gettext("Entry added."))
         |> refresh_entries()}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}
    end
  end

  @impl true
  def handle_event("update_entry", %{"entry_id" => id, "entry" => entry_params}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Dictionaries.get_entry!(current_user.id, id) do
      entry ->
        case Dictionaries.update_entry(entry, entry_params) do
          {:ok, _entry} ->
            {:noreply,
             socket
             |> assign(:editing_entry, nil)
             |> put_flash(:info, gettext("Entry updated."))
             |> refresh_entries()}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}
        end
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, gettext("Entry not found."))}
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Dictionaries.get_entry!(current_user.id, id) do
      entry ->
        Dictionaries.delete_entry(entry)
        {:noreply, put_flash(socket, :info, gettext("Entry deleted.")) |> refresh_entries()}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, gettext("Entry not found."))}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Dictionaries.get_entry!(current_user.id, id) do
      entry -> {:noreply, assign(socket, :editing_entry, entry)}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, gettext("Entry not found."))}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_entry, nil)}
  end

  @impl true
  def handle_event("open_send_to_chat", %{"id" => id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    case Dictionaries.get_entry!(current_user.id, id) do
      entry ->
        conversations = Chat.list_conversations(current_user.id, limit: 100)

        {:noreply,
         socket
         |> assign(:send_to_chat_entry, entry)
         |> assign(:conversations, conversations)}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, gettext("Entry not found."))}
  end

  @impl true
  def handle_event("close_send_to_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:send_to_chat_entry, nil)
     |> assign(:conversations, [])}
  end

  @impl true
  def handle_event("send_to_chat", %{"conversation_id" => conversation_id}, socket) do
    entry = socket.assigns.send_to_chat_entry
    current_user = socket.assigns.current_scope.current_user

    if entry do
      case Chat.get_conversation(current_user.id, conversation_id) do
        nil ->
          {:noreply, put_flash(socket, :error, gettext("Conversation not found."))}

        _conversation ->
          Dictionaries.send_entry_to_chat(entry, conversation_id, current_user.id)

          {:noreply,
           socket
           |> assign(:send_to_chat_entry, nil)
           |> assign(:conversations, [])
           |> put_flash(:info, gettext("Sent to chat dictionary."))}
      end
    else
      {:noreply, socket}
    end
  end

  defp refresh_entries(socket) do
    dictionary = socket.assigns.main_dictionary
    query = socket.assigns.search_query
    category = socket.assigns.selected_category

    entries =
      Dictionaries.list_entries(dictionary.id,
        search: query,
        category: category
      )

    categories = Dictionaries.list_categories(socket.assigns.current_scope.current_user.id, nil)

    socket
    |> assign(:entries, entries)
    |> assign(:categories, categories)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%\{.*?\}", msg, fn _ ->
        to_string(Keyword.get(opts, String.to_atom(String.slice(msg, 2, -2)), ""))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  def conversation_label(conversation, current_user_id) do
    cond do
      conversation.classroom_id && conversation.classroom ->
        conversation.classroom.name || gettext("Classroom")

      conversation.is_group ->
        conversation.title || gettext("Group Chat")

      true ->
        other = Chat.get_other_participant(conversation, current_user_id)
        display_name(other)
    end
  end

  defp display_name(%{user: %{profile: %{display_name: name}}})
       when is_binary(name) and name != "",
       do: name

  defp display_name(%{user: %{name: name}}) when is_binary(name) and name != "", do: name
  defp display_name(_), do: gettext("Anonymous")

  @doc """
  Splits a dictionary value into plain text and linked word segments.

  Text like |食べる| is rendered as a link to the word detail page.
  """
  def render_dictionary_value(value) when is_binary(value) do
    regex = ~r/\|([^|]+)\|/

    if Regex.match?(regex, value) do
      Regex.split(regex, value, include_captures: true, trim: true)
      |> Enum.map(fn segment ->
        case Regex.run(regex, segment) do
          [_, word] -> {:link, word}
          _ -> {:text, segment}
        end
      end)
    else
      [{:text, value}]
    end
  end

  def render_dictionary_value(_), do: [{:text, ""}]
end
