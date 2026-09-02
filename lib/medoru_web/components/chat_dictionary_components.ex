defmodule MedoruWeb.ChatDictionaryComponents do
  @moduledoc """
  Function components for the chat dictionary drawer.
  """

  use Phoenix.Component
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.CoreComponents, only: [icon: 1]

  use MedoruWeb, :verified_routes

  alias Medoru.Social.UserRelation

  attr :open, :boolean, required: true
  attr :dictionary, :any, required: true
  attr :enabled, :boolean, required: true
  attr :active_tab, :string, required: true
  attr :entries, :list, required: true
  attr :categories, :list, default: []
  attr :aliases, :list, default: []
  attr :current_user, :map, required: true
  attr :editing_entry, :any, default: nil
  attr :add_from_message, :any, default: nil
  attr :search_query, :string, default: ""
  attr :selected_category, :string, default: nil
  attr :sort, :string, default: "key_asc"
  attr :page, :integer, default: 1
  attr :total_pages, :integer, default: 1
  attr :total_entries, :integer, default: 0

  def chat_dictionary_drawer(assigns) do
    ~H"""
    <%= if @open do %>
      <div class="fixed inset-0 z-40 flex justify-end">
        <%!-- Backdrop --%>
        <div
          class="absolute inset-0 bg-black/40 backdrop-blur-sm"
          phx-click="close_dictionary"
        >
        </div>

        <%!-- Panel --%>
        <div class="relative w-full max-w-xl h-full bg-base-100 shadow-2xl flex flex-col">
          <%!-- Header --%>
          <div class="flex items-center gap-3 px-4 py-3 border-b border-base-300 bg-base-100 shrink-0">
            <button
              type="button"
              phx-click="close_dictionary"
              class="text-secondary hover:text-primary transition-colors"
              title={gettext("Back to chat")}
            >
              <.icon name="hero-arrow-left" class="w-5 h-5" />
            </button>
            <h2 class="font-medium text-base-content flex-1 min-w-0 truncate">
              {gettext("Dictionary")}
            </h2>
            <label class="flex items-center gap-2 text-sm cursor-pointer">
              <input
                type="checkbox"
                phx-click="toggle_dictionary"
                checked={@enabled}
                class="toggle toggle-primary toggle-sm"
              />
              {gettext("Enabled")}
            </label>
          </div>

          <%!-- Tabs --%>
          <div class="flex border-b border-base-300 shrink-0">
            <button
              type="button"
              phx-click="set_dictionary_tab"
              phx-value-tab="entries"
              class={[
                "flex-1 px-4 py-2 text-sm font-medium transition-colors",
                @active_tab == "entries" && "text-primary border-b-2 border-primary",
                @active_tab != "entries" && "text-base-content/60 hover:text-base-content"
              ]}
            >
              {gettext("Entries")}
            </button>
            <button
              type="button"
              phx-click="set_dictionary_tab"
              phx-value-tab="people"
              class={[
                "flex-1 px-4 py-2 text-sm font-medium transition-colors",
                @active_tab == "people" && "text-primary border-b-2 border-primary",
                @active_tab != "people" && "text-base-content/60 hover:text-base-content"
              ]}
            >
              {gettext("People")}
            </button>
          </div>

          <%!-- Body --%>
          <div class="flex-1 overflow-y-auto p-4">
            <%= case @active_tab do %>
              <% "people" -> %>
                <.people_tab aliases={@aliases} />
              <% _ -> %>
                <.entries_tab
                  entries={@entries}
                  categories={@categories}
                  editing_entry={@editing_entry}
                  add_from_message={@add_from_message}
                  search_query={@search_query}
                  selected_category={@selected_category}
                  sort={@sort}
                  page={@page}
                  total_pages={@total_pages}
                  total_entries={@total_entries}
                />
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  attr :entries, :list, required: true
  attr :categories, :list, default: []
  attr :editing_entry, :any, default: nil
  attr :add_from_message, :any, default: nil
  attr :search_query, :string, default: ""
  attr :selected_category, :string, default: nil
  attr :sort, :string, default: "key_asc"
  attr :page, :integer, default: 1
  attr :total_pages, :integer, default: 1
  attr :total_entries, :integer, default: 0

  defp entries_tab(assigns) do
    assigns =
      assigns
      |> assign(:grouped?, assigns.sort == "category")
      |> assign(:groups, group_entries(assigns.entries, assigns.sort))

    ~H"""
    <div class="space-y-4">
      <.entry_form
        editing_entry={@editing_entry}
        add_from_message={@add_from_message}
        categories={@categories}
      />

      <.entries_toolbar
        search_query={@search_query}
        categories={@categories}
        selected_category={@selected_category}
        sort={@sort}
      />

      <%= if @entries == [] do %>
        <div class="text-center py-10 text-secondary">
          <.icon name="hero-book-open" class="w-12 h-12 mx-auto mb-3 opacity-40" />
          <p>
            <%= if @search_query != "" or @selected_category do %>
              {gettext("No entries match your filters.")}
            <% else %>
              {gettext("No dictionary entries yet.")}
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="space-y-2">
          <%= if @grouped? do %>
            <%= for {category, group_entries} <- @groups do %>
              <div class="pt-2 first:pt-0">
                <p class="px-1 pb-1 text-xs font-semibold uppercase tracking-wide text-base-content/50">
                  {category}
                </p>
                <div class="space-y-2">
                  <%= for entry <- group_entries do %>
                    <.entry_row entry={entry} />
                  <% end %>
                </div>
              </div>
            <% end %>
          <% else %>
            <%= for entry <- @entries do %>
              <.entry_row entry={entry} />
            <% end %>
          <% end %>
        </div>

        <.entries_pagination
          page={@page}
          total_pages={@total_pages}
          total_entries={@total_entries}
        />
      <% end %>
    </div>
    """
  end

  attr :search_query, :string, default: ""
  attr :categories, :list, default: []
  attr :selected_category, :string, default: nil
  attr :sort, :string, default: "key_asc"

  defp entries_toolbar(assigns) do
    ~H"""
    <div class="space-y-2">
      <form phx-change="dictionary_search">
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40"
          />
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder={gettext("Search keys...")}
            phx-debounce="300"
            class="w-full pl-9 pr-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          />
        </div>
      </form>

      <div class="flex gap-2">
        <form phx-change="dictionary_category" class="flex-1 min-w-0">
          <select
            name="category"
            class="w-full px-2 py-1.5 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          >
            <option value="">{gettext("All categories")}</option>
            <%= for category <- @categories do %>
              <option value={category} selected={@selected_category == category}>
                {category}
              </option>
            <% end %>
          </select>
        </form>

        <form phx-change="dictionary_sort" class="flex-1 min-w-0">
          <select
            name="sort"
            class="w-full px-2 py-1.5 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          >
            <option value="key_asc" selected={@sort == "key_asc"}>{gettext("Key A→Z")}</option>
            <option value="key_desc" selected={@sort == "key_desc"}>{gettext("Key Z→A")}</option>
            <option value="newest" selected={@sort == "newest"}>{gettext("Newest first")}</option>
            <option value="oldest" selected={@sort == "oldest"}>{gettext("Oldest first")}</option>
            <option value="category" selected={@sort == "category"}>{gettext("By category")}</option>
          </select>
        </form>
      </div>
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :total_entries, :integer, required: true

  defp entries_pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2 pt-1 text-sm text-base-content/60">
      <button
        type="button"
        phx-click="dictionary_page"
        phx-value-page={@page - 1}
        disabled={@page <= 1}
        class="p-1.5 rounded-lg hover:bg-base-200 text-base-content/60 hover:text-primary transition-colors disabled:opacity-30 disabled:pointer-events-none"
        title={gettext("Previous page")}
      >
        <.icon name="hero-chevron-left" class="w-4 h-4" />
      </button>

      <span class="text-xs">
        {gettext("Page %{page} of %{total} · %{count} entries",
          page: @page,
          total: @total_pages,
          count: @total_entries
        )}
      </span>

      <button
        type="button"
        phx-click="dictionary_page"
        phx-value-page={@page + 1}
        disabled={@page >= @total_pages}
        class="p-1.5 rounded-lg hover:bg-base-200 text-base-content/60 hover:text-primary transition-colors disabled:opacity-30 disabled:pointer-events-none"
        title={gettext("Next page")}
      >
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  # Groups a page of entries under category headers (uncategorized -> "main").
  defp group_entries(entries, "category") do
    entries
    |> Enum.chunk_by(fn e -> String.downcase(e.category || "main") end)
    |> Enum.map(fn group ->
      label = hd(group).category || "main"
      {label, group}
    end)
  end

  defp group_entries(_entries, _sort), do: []

  attr :entry, :any, required: true

  defp entry_row(assigns) do
    ~H"""
    <div class="p-3 bg-base-200 rounded-xl border border-base-300">
      <div class="flex items-start justify-between gap-2">
        <div class="flex-1 min-w-0">
          <div class="flex flex-wrap items-baseline gap-x-2 gap-y-1">
            <p class="text-sm font-medium text-base-content break-words">{@entry.key}</p>
            <%= if @entry.category do %>
              <span class="px-2 py-0.5 bg-base-300 text-base-content/70 text-xs rounded-full">
                {@entry.category}
              </span>
            <% end %>
          </div>
          <p class="mt-1 text-sm text-secondary break-words">
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
          </p>
        </div>
        <div class="flex items-center gap-1 shrink-0">
          <button
            type="button"
            phx-click="start_edit_dictionary_entry"
            phx-value-id={@entry.id}
            class="p-1.5 text-base-content/40 hover:text-primary transition-colors"
            title={gettext("Edit")}
          >
            <.icon name="hero-pencil" class="w-4 h-4" />
          </button>
          <button
            type="button"
            phx-click="copy_entry_to_main"
            phx-value-id={@entry.id}
            class="p-1.5 text-base-content/40 hover:text-primary transition-colors"
            title={gettext("Copy to main dictionary")}
          >
            <.icon name="hero-arrow-up-tray" class="w-4 h-4" />
          </button>
          <button
            type="button"
            phx-click="delete_dictionary_entry"
            phx-value-id={@entry.id}
            data-confirm={gettext("Delete this entry?")}
            class="p-1.5 text-base-content/40 hover:text-error transition-colors"
            title={gettext("Delete")}
          >
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :editing_entry, :any, default: nil
  attr :add_from_message, :any, default: nil
  attr :categories, :list, default: []

  defp entry_form(assigns) do
    editing? = assigns.editing_entry != nil
    entry = assigns.editing_entry || %{key: "", value: "", category: nil, match_mode: "prefix"}

    value =
      if assigns.add_from_message && is_nil(assigns.editing_entry) do
        assigns.add_from_message.content
      else
        entry.value
      end

    category = entry.category || ""
    is_substring = entry.match_mode == "substring"

    submit_event = if editing?, do: "update_dictionary_entry", else: "create_dictionary_entry"

    assigns =
      assigns
      |> assign(:editing?, editing?)
      |> assign(:entry, entry)
      |> assign(:value, value)
      |> assign(:category, category)
      |> assign(:is_substring, is_substring)
      |> assign(:submit_event, submit_event)

    ~H"""
    <form
      phx-submit={@submit_event}
      class="p-3 bg-base-200 rounded-xl border border-base-300 space-y-3"
    >
      <%= if @editing? do %>
        <input type="hidden" name="entry_id" value={@entry.id} />
      <% end %>

      <div>
        <label class="block text-xs font-medium text-base-content/70 mb-1">
          {gettext("Key (what you type after /d)")}
        </label>
        <input
          type="text"
          name="entry[key]"
          value={@entry.key}
          placeholder={gettext("e.g. hello")}
          required
          class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
        />
      </div>

      <div>
        <label class="block text-xs font-medium text-base-content/70 mb-1">
          {gettext("Value (what gets inserted)")}
        </label>
        <textarea
          name="entry[value]"
          rows="2"
          placeholder={gettext("e.g. こんにちは or |食べる|")}
          required
          class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"
        >{@value}</textarea>
      </div>

      <div class="flex gap-2">
        <div class="flex-1">
          <label class="block text-xs font-medium text-base-content/70 mb-1">
            {gettext("Category")}
          </label>
          <input
            type="text"
            name="entry[category]"
            value={@category}
            list="dictionary-categories"
            placeholder={gettext("e.g. greetings")}
            class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          />
          <datalist id="dictionary-categories">
            <%= for cat <- @categories do %>
              <option value={cat}></option>
            <% end %>
          </datalist>
        </div>
        <div class="flex items-end">
          <label class="flex items-center gap-2 text-sm cursor-pointer pb-2">
            <input
              type="hidden"
              name="entry[match_mode]"
              value={if @is_substring, do: "substring", else: "prefix"}
            />
            <input
              type="checkbox"
              name="entry[match_mode]"
              value="substring"
              checked={@is_substring}
              class="checkbox checkbox-primary checkbox-sm"
            />
            {gettext("Substring")}
          </label>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button
          type="submit"
          class="btn btn-primary btn-sm"
        >
          <%= if @editing? do %>
            {gettext("Update")}
          <% else %>
            {gettext("Add")}
          <% end %>
        </button>
        <%= if @editing? do %>
          <button
            type="button"
            phx-click="cancel_edit_dictionary_entry"
            class="btn btn-ghost btn-sm"
          >
            {gettext("Cancel")}
          </button>
        <% end %>
      </div>
    </form>
    """
  end

  attr :aliases, :list, required: true

  defp people_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if @aliases == [] do %>
        <p class="text-center text-secondary py-8">{gettext("No other people in this chat.")}</p>
      <% else %>
        <%= for alias_map <- @aliases do %>
          <.relation_form
            target_user_id={alias_map.user_id}
            display_name={alias_map.display_name}
            ref_index={alias_map.ref_index}
            nicknames={alias_map.nicknames}
            relationship_type={alias_map.relationship_type}
            address_style={alias_map.address_style}
            description={alias_map.description}
          />
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :target_user_id, :string, required: true
  attr :display_name, :string, required: true
  attr :ref_index, :any, default: nil
  attr :nicknames, :list, default: []
  attr :relationship_type, :string, default: nil
  attr :address_style, :string, default: nil
  attr :description, :string, default: nil

  def relation_form(assigns) do
    ~H"""
    <form
      phx-submit="save_user_relation"
      class="p-3 bg-base-200 rounded-xl border border-base-300 space-y-3"
    >
      <input type="hidden" name="target_user_id" value={@target_user_id} />

      <div class="flex items-center gap-2">
        <%= if @ref_index do %>
          <span class="text-xs font-mono text-primary">/{@ref_index}</span>
        <% end %>
        <p class="font-medium text-base-content">{@display_name}</p>
      </div>

      <div>
        <label class="block text-xs text-base-content/70 mb-1">
          {gettext("Nicknames (comma separated)")}
        </label>
        <input
          type="text"
          name="relation[nicknames]"
          value={Enum.join(@nicknames, ", ")}
          placeholder={gettext("nickname1, nickname2")}
          class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
        />
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div>
          <label class="block text-xs text-base-content/70 mb-1">
            {gettext("Relation")}
          </label>
          <select
            name="relation[relationship_type]"
            class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          >
            <option value="">{gettext("None")}</option>
            <%= for type <- UserRelation.relationship_types() do %>
              <option value={type} selected={@relationship_type == type}>
                {type}
              </option>
            <% end %>
          </select>
        </div>
        <div>
          <label class="block text-xs text-base-content/70 mb-1">
            {gettext("Address style")}
          </label>
          <select
            name="relation[address_style]"
            class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30"
          >
            <option value="">{gettext("None")}</option>
            <%= for style <- UserRelation.address_styles() do %>
              <option value={style} selected={@address_style == style}>
                {style}
              </option>
            <% end %>
          </select>
        </div>
      </div>

      <div>
        <label class="block text-xs text-base-content/70 mb-1">
          {gettext("Description")}
        </label>
        <textarea
          name="relation[description]"
          rows="2"
          placeholder={gettext("Notes about this person...")}
          class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"
        ><%= @description %></textarea>
      </div>

      <button type="submit" class="btn btn-primary btn-sm">
        {gettext("Save")}
      </button>
    </form>
    """
  end

  defp render_dictionary_value(value) when is_binary(value) do
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

  defp render_dictionary_value(_), do: [{:text, ""}]
end
