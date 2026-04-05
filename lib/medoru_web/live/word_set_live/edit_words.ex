defmodule MedoruWeb.WordSetLive.EditWords do
  @moduledoc """
  LiveView for adding, removing, and reordering words in a word set.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordSets
  alias Medoru.Content

  @max_words 100

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Edit Words"))
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    user = socket.assigns.current_scope.current_user
    word_set = WordSets.get_word_set!(id)

    # Ensure user owns this word set
    if word_set.user_id != user.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to edit this word set."))
       |> push_navigate(to: ~p"/words/sets")}
    else
      word_set_words = load_word_set_words(word_set)

      {:noreply,
       socket
       |> assign(:word_set, word_set)
       |> assign(:word_set_words, word_set_words)
       |> assign(:can_add_more, length(word_set_words) < @max_words)
       |> assign(:max_words, @max_words)}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)

    # Allow 1-character searches for Japanese (e.g., に, ー)
    if query == "" do
      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_results, [])
       |> assign(:search_loading, false)}
    else
      # Debounce search
      Process.send_after(self(), {:do_search, query}, 200)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_loading, true)}
    end
  end



  @impl true
  def handle_event("add_word", %{"word_id" => word_id}, socket) do
    word_set = socket.assigns.word_set

    if length(socket.assigns.word_set_words) >= @max_words do
      {:noreply, put_flash(socket, :error, gettext("Word set is full (max %{max} words)", max: @max_words))}
    else
      case WordSets.add_word_to_set(word_set, word_id) do
        {:ok, updated_set} ->
          # Reload word set with preloaded words
          refreshed_set = WordSets.get_word_set!(updated_set.id)
          word_set_words = load_word_set_words(refreshed_set)

          {:noreply,
           socket
           |> assign(:word_set, refreshed_set)
           |> assign(:word_set_words, word_set_words)
           |> assign(:can_add_more, length(word_set_words) < @max_words)
           |> assign(:search_query, "")
           |> assign(:search_results, [])}

        {:error, :max_words_reached} ->
          {:noreply, put_flash(socket, :error, gettext("Word set is full (max %{max} words)", max: @max_words))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to add word. It may already be in the set."))}
      end
    end
  end

  @impl true
  def handle_event("remove_word", %{"word_id" => word_id}, socket) do
    word_set = socket.assigns.word_set

    case WordSets.remove_word_from_set(word_set, word_id) do
      {:ok, updated_set} ->
        # Reload word set with preloaded words
        refreshed_set = WordSets.get_word_set!(updated_set.id)
        word_set_words = load_word_set_words(refreshed_set)

        {:noreply,
         socket
         |> assign(:word_set, refreshed_set)
         |> assign(:word_set_words, word_set_words)
         |> assign(:can_add_more, length(word_set_words) < @max_words)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove word."))}
    end
  end

  @impl true
  def handle_event("move_up", %{"word_id" => word_id}, socket) do
    word_set_words = socket.assigns.word_set_words
    current_index = Enum.find_index(word_set_words, fn wsw -> wsw.word_id == word_id end)

    if current_index && current_index > 0 do
      new_word_ids =
        word_set_words
        |> Enum.map(& &1.word_id)
        |> List.delete_at(current_index)
        |> List.insert_at(current_index - 1, word_id)

      WordSets.reorder_words(socket.assigns.word_set.id, new_word_ids)
      
      # Reload word set with preloaded words
      refreshed_set = WordSets.get_word_set!(socket.assigns.word_set.id)
      updated_words = load_word_set_words(refreshed_set)

      {:noreply, assign(socket, :word_set_words, updated_words)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_down", %{"word_id" => word_id}, socket) do
    word_set_words = socket.assigns.word_set_words
    current_index = Enum.find_index(word_set_words, fn wsw -> wsw.word_id == word_id end)
    last_index = length(word_set_words) - 1

    if current_index && current_index < last_index do
      new_word_ids =
        word_set_words
        |> Enum.map(& &1.word_id)
        |> List.delete_at(current_index)
        |> List.insert_at(current_index + 1, word_id)

      WordSets.reorder_words(socket.assigns.word_set.id, new_word_ids)
      
      # Reload word set with preloaded words
      refreshed_set = WordSets.get_word_set!(socket.assigns.word_set.id)
      updated_words = load_word_set_words(refreshed_set)

      {:noreply, assign(socket, :word_set_words, updated_words)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:do_search, query}, socket) do
    # Only process if query hasn't changed
    if socket.assigns.search_query == query do
      results = Content.search_words(query, limit: 10)

      # Filter out words already in the set
      existing_ids = Enum.map(socket.assigns.word_set_words, & &1.word_id)
      filtered_results = Enum.reject(results, fn word -> word.id in existing_ids end)

      {:noreply,
       socket
       |> assign(:search_results, filtered_results)
       |> assign(:search_loading, false)}
    else
      {:noreply, socket}
    end
  end

  defp load_word_set_words(word_set) do
    word_set.word_set_words
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn wsw ->
      %{
        word_id: wsw.word_id,
        word: wsw.word,
        position: wsw.position
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">
              {gettext("Edit Words: %{name}", name: @word_set.name)}
            </h1>
            <p class="text-secondary mt-2">
              {gettext("Add up to %{max} words to your set. Current: %{count}", 
                max: @max_words, count: length(@word_set_words))}
            </p>
          </div>
          <.link
            navigate={~p"/words/sets/#{@word_set.id}"}
            class="px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium text-center transition-colors"
          >
            {gettext("Done")}
          </.link>
        </div>

        <%!-- Search Section --%>
        <%= if @can_add_more do %>
          <div class="card bg-base-100 border border-base-300 mb-6">
            <div class="card-body">
              <label class="block text-sm font-medium text-base-content mb-2">
                {gettext("Search Words")}
              </label>
              <div class="relative">
                <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-secondary" />
                <form phx-change="search" class="contents">
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    phx-debounce="300"
                    placeholder={gettext("Search words...")}
                    class="w-full pl-10 pr-10 py-3 bg-base-100 border border-base-300 rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  />
                </form>
                <%= if @search_loading do %>
                  <div class="absolute right-3 top-1/2 -translate-y-1/2">
                    <div class="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin"></div>
                  </div>
                <% end %>
              </div>

              <%!-- Search Results --%>
              <%= if length(@search_results) > 0 do %>
                <div class="mt-4 space-y-2 max-h-64 overflow-y-auto">
                  <%= for word <- @search_results do %>
                    <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div class="flex items-center gap-3">
                        <span class="text-lg font-medium text-base-content">{word.text}</span>
                        <span class="text-secondary">{word.reading}</span>
                        <span class="text-sm text-secondary">- {word.meaning}</span>
                      </div>
                      <button
                        phx-click="add_word"
                        phx-value-word_id={word.id}
                        class="px-3 py-1 bg-primary hover:bg-primary/90 text-primary-content rounded-lg text-sm font-medium transition-colors"
                      >
                        {gettext("Add")}
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%= if @search_query != "" && !@search_loading && length(@search_results) == 0 do %>
                <p class="mt-4 text-secondary text-center">
                  {gettext("No words found matching '%{query}'", query: @search_query)}
                </p>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="p-4 bg-warning/10 border border-warning/30 rounded-lg mb-6">
            <div class="flex items-center gap-3">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning" />
              <p class="text-warning-content">
                {gettext("Word set is full. Remove some words to add more.")}
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Words List --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="text-lg font-semibold text-base-content mb-4">
              {gettext("Words in Set (%{count})", count: length(@word_set_words))}
            </h2>

            <%= if length(@word_set_words) == 0 do %>
              <div class="text-center py-12">
                <.icon name="hero-inbox" class="w-16 h-16 mx-auto text-secondary mb-4" />
                <h3 class="text-lg font-medium text-base-content mb-2">
                  {gettext("No words yet")}
                </h3>
                <p class="text-secondary">
                  {gettext("Search above to add words to your set.")}
                </p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for {wsw, index} <- Enum.with_index(@word_set_words) do %>
                  <div class="flex items-center gap-3 p-3 bg-base-200 rounded-lg group">
                    <%!-- Position Number --%>
                    <span class="w-8 h-8 flex items-center justify-center bg-base-300 rounded-lg text-sm font-medium text-secondary shrink-0">
                      {index + 1}
                    </span>

                    <%!-- Word Info --%>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="text-lg font-medium text-base-content">{wsw.word.text}</span>
                        <span class="text-secondary">{wsw.word.reading}</span>
                      </div>
                      <p class="text-sm text-secondary truncate">{wsw.word.meaning}</p>
                    </div>

                    <%!-- JLPT Level Badge --%>
                    <%= if wsw.word.difficulty do %>
                      <span class="px-2 py-1 bg-base-300 rounded text-xs font-medium text-secondary shrink-0">
                        N{wsw.word.difficulty}
                      </span>
                    <% end %>

                    <%!-- Actions --%>
                    <div class="flex items-center gap-1 shrink-0 opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                      <button
                        phx-click="move_up"
                        phx-value-word_id={wsw.word_id}
                        disabled={index == 0}
                        class="p-1.5 hover:bg-base-300 rounded-lg disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                      >
                        <.icon name="hero-chevron-up" class="w-4 h-4 text-secondary" />
                      </button>
                      <button
                        phx-click="move_down"
                        phx-value-word_id={wsw.word_id}
                        disabled={index == length(@word_set_words) - 1}
                        class="p-1.5 hover:bg-base-300 rounded-lg disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                      >
                        <.icon name="hero-chevron-down" class="w-4 h-4 text-secondary" />
                      </button>
                      <button
                        phx-click="remove_word"
                        phx-value-word_id={wsw.word_id}
                        data-confirm={gettext("Remove this word from the set?")}
                        class="p-1.5 hover:bg-error/10 rounded-lg transition-colors"
                      >
                        <.icon name="hero-trash" class="w-4 h-4 text-error" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
