defmodule MedoruWeb.WordSetLive.Show do
  @moduledoc """
  LiveView for viewing a word set and its words.
  Displays words with N1-N5 and SL1-SL6 levels like the main /words view.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordSets
  alias Medoru.Content

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:page_title, gettext("Word Set"))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    id = params["id"]
    user = socket.assigns.current_scope.current_user
    page = parse_page(params["page"])
    word_type = parse_word_type(params["word_type"])

    {word_set, words_result} =
      WordSets.get_word_set_with_words_paginated(id,
        page: page,
        per_page: @per_page,
        word_type: word_type
      )

    # Check if user owns this word set
    is_owner = user && word_set.user_id == user.id

    {:noreply,
     socket
     |> assign(:word_set, word_set)
     |> assign(:words, words_result.words)
     |> assign(:total_count, words_result.total_count)
     |> assign(:total_pages, words_result.total_pages)
     |> assign(:page, page)
     |> assign(:word_type, word_type)
     |> assign(:is_owner, is_owner)
     |> assign(:page_title, word_set.name)
     |> assign(:copy_modal_open, false)
     |> assign(:copy_search_term, "")
     |> assign(:copy_search_results, [])
     |> assign(:copy_selected_target, nil)
     |> assign(:copy_error, nil)}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    word_type = socket.assigns.word_type

    {_word_set, words_result} =
      WordSets.get_word_set_with_words_paginated(socket.assigns.word_set.id,
        page: page,
        per_page: @per_page,
        word_type: word_type
      )

    {:noreply,
     socket
     |> assign(:words, words_result.words)
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("filter_word_type", %{"word_type" => word_type}, socket) do
    word_type = if word_type == "", do: nil, else: String.to_existing_atom(word_type)

    {_word_set, words_result} =
      WordSets.get_word_set_with_words_paginated(socket.assigns.word_set.id,
        page: 1,
        per_page: @per_page,
        word_type: word_type
      )

    {:noreply,
     socket
     |> assign(:words, words_result.words)
     |> assign(:page, 1)
     |> assign(:word_type, word_type)
     |> assign(:total_count, words_result.total_count)
     |> assign(:total_pages, words_result.total_pages)}
  end

  @impl true
  def handle_event("delete_test", _params, socket) do
    word_set = socket.assigns.word_set

    if socket.assigns.is_owner do
      case WordSets.delete_practice_test(word_set) do
        {:ok, updated_set} ->
          {:noreply,
           socket
           |> assign(:word_set, updated_set)
           |> put_flash(:info, gettext("Practice test deleted."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete practice test."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You don't have permission to do this."))}
    end
  end

  # Copy to Word Set event handlers
  @impl true
  def handle_event("open_copy_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:copy_modal_open, true)
     |> assign(:copy_search_term, "")
     |> assign(:copy_search_results, [])
     |> assign(:copy_selected_target, nil)
     |> assign(:copy_error, nil)}
  end

  @impl true
  def handle_event("close_copy_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:copy_modal_open, false)
     |> assign(:copy_search_term, "")
     |> assign(:copy_search_results, [])
     |> assign(:copy_selected_target, nil)
     |> assign(:copy_error, nil)}
  end

  @impl true
  def handle_event("update_copy_search", %{"search" => search_term}, socket) do
    {:noreply, assign(socket, :copy_search_term, search_term)}
  end

  @impl true
  def handle_event("search_word_sets", params, socket) do
    # Get search term from event params (keybaord enter) or socket assign (button click)
    search_term =
      case params do
        %{"value" => value} when is_binary(value) -> String.trim(value)
        _ -> String.trim(socket.assigns.copy_search_term)
      end

    if search_term == "" do
      {:noreply, assign(socket, :copy_search_results, [])}
    else
      user_id = socket.assigns.current_scope.current_user.id
      source_id = socket.assigns.word_set.id

      results = WordSets.search_word_sets_for_copy(user_id, source_id, search_term)
      {:noreply, assign(socket, :copy_search_results, results)}
    end
  end

  @impl true
  def handle_event("select_target_word_set", %{"id" => target_id, "name" => name}, socket) do
    target = %{id: target_id, name: name}

    {:noreply,
     socket
     |> assign(:copy_selected_target, target)
     |> assign(:copy_error, nil)}
  end

  @impl true
  def handle_event("clear_selected_target", _, socket) do
    {:noreply,
     socket
     |> assign(:copy_selected_target, nil)
     |> assign(:copy_error, nil)}
  end

  @impl true
  def handle_event("copy_to_word_set", _, socket) do
    source_id = socket.assigns.word_set.id
    target = socket.assigns.copy_selected_target

    if target do
      case WordSets.copy_words_to_word_set(source_id, target.id) do
        {:ok, updated_target} ->
          {:noreply,
           socket
           |> assign(:copy_modal_open, false)
           |> assign(:copy_search_term, "")
           |> assign(:copy_search_results, [])
           |> assign(:copy_selected_target, nil)
           |> assign(:copy_error, nil)
           |> put_flash(:info, gettext("Words copied to '%{name}'", name: updated_target.name))
           |> push_navigate(to: ~p"/words/sets/#{updated_target.id}")}

        {:error, :would_overflow} ->
          {:noreply,
           socket
           |> assign(:copy_error, gettext("Cannot copy: would exceed maximum word limit"))
           |> assign(:copy_selected_target, nil)}

        {:error, _} ->
          {:noreply,
           socket
           |> assign(:copy_error, gettext("Failed to copy words"))}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper for template
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end

  # Private helpers
  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  defp parse_word_type(nil), do: nil
  defp parse_word_type(""), do: nil

  defp parse_word_type(word_type) when is_binary(word_type) do
    valid_types = ["noun", "verb", "adjective", "adverb", "particle", "pronoun", "counter", "expression", "other"]
    if word_type in valid_types do
      String.to_existing_atom(word_type)
    else
      nil
    end
  end

  defp parse_word_type(_), do: nil

  # Word type options for the filter dropdown
  def word_type_options do
    [
      {gettext("All Types"), nil},
      {gettext("Noun"), :noun},
      {gettext("Verb"), :verb},
      {gettext("Adjective"), :adjective},
      {gettext("Adverb"), :adverb},
      {gettext("Particle"), :particle},
      {gettext("Pronoun"), :pronoun},
      {gettext("Counter"), :counter},
      {gettext("Expression"), :expression},
      {gettext("Other"), :other}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <h1 class="text-3xl font-bold text-base-content">{@word_set.name}</h1>
              <%= if @word_set.description && @word_set.description != "" do %>
                <p class="text-secondary mt-2">{@word_set.description}</p>
              <% end %>
              <div class="flex items-center gap-4 mt-3 text-sm text-secondary">
                <span class="flex items-center gap-1">
                  <.icon name="hero-book-open" class="w-4 h-4" />
                  {@word_set.word_count} {ngettext("word", "words", @word_set.word_count)}
                </span>
                <span class="flex items-center gap-1">
                  <.icon name="hero-calendar" class="w-4 h-4" />
                  {Calendar.strftime(@word_set.inserted_at, "%b %d, %Y")}
                </span>
              </div>
            </div>

            <%!-- Owner Actions --%>
            <%= if @is_owner do %>
              <div class="flex flex-wrap gap-2">
                <.link
                  navigate={~p"/words/sets/#{@word_set.id}/edit-words"}
                  class="px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium transition-colors"
                >
                  <.icon name="hero-pencil-square" class="w-4 h-4 inline mr-1" />
                  {gettext("Edit Words")}
                </.link>
                <.link
                  navigate={~p"/words/sets/#{@word_set.id}/edit"}
                  class="px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium transition-colors"
                >
                  <.icon name="hero-cog-6-tooth" class="w-4 h-4 inline mr-1" />
                  {gettext("Settings")}
                </.link>
                <button
                  type="button"
                  phx-click="open_copy_modal"
                  class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                >
                  <.icon name="hero-document-duplicate" class="w-4 h-4 inline mr-1" />
                  {gettext("Copy to")}
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Practice Test Section --%>
        <%= if @is_owner do %>
          <div class="card bg-base-100 border border-base-300 mb-8">
            <div class="card-body">
              <h2 class="text-lg font-semibold text-base-content mb-4">
                {gettext("Practice Test")}
              </h2>

              <%= if @word_set.practice_test_id do %>
                <div class="flex flex-col sm:flex-row items-start sm:items-center gap-4">
                  <div class="flex-1">
                    <p class="text-secondary">
                      {gettext("Test your knowledge of the words in this set.")}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <.link
                      navigate={~p"/words/sets/#{@word_set.id}/test"}
                      class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                    >
                      <.icon name="hero-play" class="w-4 h-4 inline mr-1" />
                      {gettext("Take Test")}
                    </.link>
                    <button
                      phx-click="delete_test"
                      data-confirm={
                        gettext(
                          "Delete this practice test? You'll need to recreate it to take it again."
                        )
                      }
                      class="px-4 py-2 bg-error/10 hover:bg-error/20 text-error rounded-lg font-medium transition-colors"
                    >
                      <.icon name="hero-trash" class="w-4 h-4 inline mr-1" />
                      {gettext("Delete")}
                    </button>
                  </div>
                </div>
              <% else %>
                <div class="flex flex-col sm:flex-row items-start sm:items-center gap-4">
                  <p class="text-secondary flex-1">
                    {gettext(
                      "Create a practice test to study these words with customizable question types."
                    )}
                  </p>
                  <.link
                    navigate={~p"/words/sets/#{@word_set.id}/test-config"}
                    class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                  >
                    <.icon name="hero-plus" class="w-4 h-4 inline mr-1" />
                    {gettext("Create Test")}
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Words List --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-4">
              <h2 class="text-lg font-semibold text-base-content">
                {gettext("Words")}
              </h2>

              <%!-- Word Type Filter --%>
              <form phx-change="filter_word_type" class="flex items-center gap-2">
                <label class="text-sm text-secondary">{gettext("Filter by type:")}</label>
                <select
                  name="word_type"
                  class="px-3 py-1.5 bg-base-100 border border-base-300 rounded-lg text-sm text-base-content focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"
                >
                  <%= for {label, value} <- word_type_options() do %>
                    <option value={value || ""} selected={@word_type == value}>
                      {label}
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

            <%= if length(@words) == 0 do %>
              <div class="text-center py-12">
                <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-secondary mb-4" />
                <h3 class="text-lg font-medium text-base-content mb-2">
                  {gettext("No words yet")}
                </h3>
                <%= if @is_owner do %>
                  <.link
                    navigate={~p"/words/sets/#{@word_set.id}/edit-words"}
                    class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                  >
                    {gettext("Add Words")}
                  </.link>
                <% end %>
              </div>
            <% else %>
              <%!-- Words Grid - Similar to /words view --%>
              <div class="space-y-3">
                <%= for word <- @words do %>
                  <div class="flex items-center gap-4 p-4 bg-base-200 rounded-lg hover:bg-base-300/50 transition-colors">
                    <%!-- Word Text --%>
                    <.link
                      navigate={~p"/words/#{word.id}"}
                      class="text-xl font-medium text-base-content hover:text-primary transition-colors min-w-[80px]"
                    >
                      {word.text}
                    </.link>

                    <%!-- Reading --%>
                    <span class="text-secondary min-w-[100px]">{word.reading}</span>

                    <%!-- Meaning --%>
                    <span class="flex-1 text-base-content truncate">
                      {localized_word_meaning(word, @locale)}
                    </span>

                    <%!-- Badges --%>
                    <div class="flex items-center gap-2 shrink-0">
                      <%!-- JLPT Level --%>
                      <%= if word.difficulty do %>
                        <span class="px-2 py-1 bg-base-300 rounded text-xs font-medium text-secondary">
                          N{word.difficulty}
                        </span>
                      <% end %>

                      <%!-- Word Type --%>
                      <%= if word.word_type do %>
                        <span class="px-2 py-1 bg-secondary/10 rounded text-xs font-medium text-secondary capitalize">
                          {word.word_type}
                        </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <%!-- Pagination --%>
              <%= if @total_pages > 1 do %>
                <div class="flex justify-center gap-2 mt-6">
                  <%= if @page > 1 do %>
                    <button
                      phx-click="change_page"
                      phx-value-page={@page - 1}
                      class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-base-content transition-colors"
                    >
                      <.icon name="hero-chevron-left" class="w-5 h-5" />
                    </button>
                  <% end %>

                  <span class="px-4 py-2 bg-base-100 border border-base-300 rounded-lg text-base-content">
                    {@page} / {@total_pages}
                  </span>

                  <%= if @page < @total_pages do %>
                    <button
                      phx-click="change_page"
                      phx-value-page={@page + 1}
                      class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-base-content transition-colors"
                    >
                      <.icon name="hero-chevron-right" class="w-5 h-5" />
                    </button>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Back Link --%>
        <div class="mt-8">
          <.link
            navigate={~p"/words/sets"}
            class="inline-flex items-center gap-2 text-secondary hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            {gettext("Back to My Word Sets")}
          </.link>
        </div>

        <%!-- Copy to Word Set Modal --%>
        <%= if @copy_modal_open do %>
          <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <div class="bg-base-100 rounded-2xl shadow-xl max-w-md w-full p-6">
              <h3 class="text-xl font-bold text-base-content mb-4">
                {gettext("Copy to Word Set")}
              </h3>
              <p class="text-secondary mb-4">
                {gettext("Copy words from '%{source}' to another word set", source: @word_set.name)}
              </p>

              <%!-- Error message --%>
              <%= if @copy_error do %>
                <div class="bg-error/10 text-error rounded-lg p-3 mb-4">
                  {@copy_error}
                </div>
              <% end %>

              <%!-- Search --%>
              <%= if !@copy_selected_target do %>
                <div class="mb-4">
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Search for word set")}
                  </label>
                  <div class="flex gap-2">
                    <input
                      type="text"
                      name="search"
                      value={@copy_search_term}
                      phx-change="update_copy_search"
                      phx-keydown="search_word_sets"
                      phx-key="Enter"
                      placeholder={gettext("Enter word set name...")}
                      class="flex-1 px-4 py-2 rounded-lg border border-base-300 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none"
                    />
                    <button
                      type="button"
                      phx-click="search_word_sets"
                      class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                    >
                      {gettext("Search")}
                    </button>
                  </div>
                </div>

                <%!-- Search Results --%>
                <%= if @copy_search_results != [] do %>
                  <div class="space-y-2 mb-4 max-h-48 overflow-y-auto">
                    <%= for word_set <- @copy_search_results do %>
                      <button
                        type="button"
                        phx-click="select_target_word_set"
                        phx-value-id={word_set.id}
                        phx-value-name={word_set.name}
                        class="w-full text-left p-3 rounded-lg border border-base-200 hover:border-primary hover:bg-primary/5 transition-colors"
                      >
                        <div class="font-medium text-base-content">{word_set.name}</div>
                        <div class="text-sm text-secondary">
                          {word_set.word_count} {ngettext("word", "words", word_set.word_count)}
                        </div>
                      </button>
                    <% end %>
                  </div>
                <% end %>

                <%= if @copy_search_term != "" && @copy_search_results == [] do %>
                  <p class="text-secondary text-center py-4">
                    {gettext("No word sets found")}
                  </p>
                <% end %>
              <% else %>
                <%!-- Selected Target --%>
                <div class="mb-4">
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Selected word set")}
                  </label>
                  <div class="flex items-center justify-between p-3 rounded-lg border border-primary bg-primary/5">
                    <div>
                      <div class="font-medium text-base-content">{@copy_selected_target.name}</div>
                    </div>
                    <button
                      type="button"
                      phx-click="clear_selected_target"
                      class="p-1 text-secondary hover:text-error transition-colors"
                    >
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>
                  </div>
                </div>
              <% end %>

              <%!-- Actions --%>
              <div class="flex gap-3 justify-end">
                <button
                  type="button"
                  phx-click="close_copy_modal"
                  class="btn btn-ghost"
                >
                  {gettext("Back")}
                </button>
                <button
                  type="button"
                  phx-click="copy_to_word_set"
                  disabled={!@copy_selected_target}
                  class={[
                    "btn btn-primary",
                    !@copy_selected_target && "btn-disabled opacity-50"
                  ]}
                >
                  {gettext("Copy")}
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
