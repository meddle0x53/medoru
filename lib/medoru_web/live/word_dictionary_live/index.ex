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
     |> assign(:sort, "key_asc")
     |> assign(:page, 1)
     |> assign(:per_page, 50)
     |> assign(:total_entries, 0)
     |> assign(:total_pages, 1)
     |> assign(:send_to_chat_entry, nil)
     |> assign(:conversations, [])
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:page, 1)
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_category", %{"category" => category}, socket) do
    category = if category in ["", nil], do: nil, else: category

    {:noreply,
     socket
     |> assign(:selected_category, category)
     |> assign(:page, 1)
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_sort", %{"sort" => sort}, socket) do
    sort = if sort in Dictionaries.sort_orders(), do: sort, else: "key_asc"

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> refresh_entries()}
  end

  @impl true
  def handle_event("set_page", %{"page" => page}, socket) do
    page =
      case Integer.parse(to_string(page)) do
        {n, _} -> max(n, 1)
        :error -> 1
      end

    {:noreply,
     socket
     |> assign(:page, page)
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

    result =
      Dictionaries.list_entries(dictionary.id,
        search: socket.assigns.search_query,
        category: socket.assigns.selected_category,
        sort: socket.assigns.sort,
        page: socket.assigns.page,
        per_page: socket.assigns.per_page
      )

    categories = Dictionaries.list_categories(socket.assigns.current_scope.current_user.id, nil)

    socket
    |> assign(:entries, result.entries)
    |> assign(:categories, categories)
    |> assign(:page, result.page)
    |> assign(:total_entries, result.total)
    |> assign(:total_pages, result.total_pages)
  end

  @doc """
  Groups a page of entries under category labels for the "category" sort order.
  Uncategorized entries are grouped under "main".
  """
  def group_by_category(entries) do
    entries
    |> Enum.chunk_by(fn e -> String.downcase(e.category || "main") end)
    |> Enum.map(fn group -> {hd(group).category || "main", group} end)
  end

  attr :entry, :any, required: true

  def entry_row(assigns) do
    ~H"""
    <div class="p-4 flex items-start gap-3 hover:bg-base-50">
      <div class="flex-1 min-w-0">
        <div class="flex flex-wrap items-baseline gap-x-2 gap-y-1">
          <div class="font-medium text-base-content break-words">
            {@entry.key}
          </div>
          <%= if @entry.category do %>
            <span class="text-xs px-2 py-0.5 bg-base-200 rounded-full text-base-content/70">
              {@entry.category}
            </span>
          <% end %>
        </div>
        <div class="mt-1 text-sm text-secondary break-words">
          <span class="text-base-content/30">→ </span>
          <%= for segment <- render_dictionary_value(@entry.value) do %>
            <%= case segment do %>
              <% {:text, text} -> %>
                {text}
              <% {:link, word} -> %>
                <.link
                  navigate={~p"/words/#{word}"}
                  class="text-primary hover:underline"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {word}
                </.link>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="flex items-center gap-2 shrink-0">
        <button
          type="button"
          phx-click="open_send_to_chat"
          phx-value-id={@entry.id}
          class="p-2 text-secondary hover:text-primary hover:bg-base-200 rounded-lg transition-colors"
          title={gettext("Send to chat dictionary")}
        >
          <.icon name="hero-paper-airplane" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="start_edit"
          phx-value-id={@entry.id}
          class="p-2 text-secondary hover:text-primary hover:bg-base-200 rounded-lg transition-colors"
          title={gettext("Edit")}
        >
          <.icon name="hero-pencil" class="w-4 h-4" />
        </button>
        <button
          type="button"
          phx-click="delete_entry"
          phx-value-id={@entry.id}
          data-confirm={gettext("Delete this entry?")}
          class="p-2 text-secondary hover:text-error hover:bg-base-200 rounded-lg transition-colors"
          title={gettext("Delete")}
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
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
