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
  def handle_params(%{"id" => id}, _url, socket) do
    user = socket.assigns.current_scope.current_user
    page = parse_page(socket.assigns[:page])

    {word_set, words_result} = WordSets.get_word_set_with_words_paginated(id, page: page, per_page: @per_page)

    # Check if user owns this word set
    is_owner = user && word_set.user_id == user.id

    {:noreply,
     socket
     |> assign(:word_set, word_set)
     |> assign(:words, words_result.words)
     |> assign(:total_count, words_result.total_count)
     |> assign(:total_pages, words_result.total_pages)
     |> assign(:page, page)
     |> assign(:is_owner, is_owner)
     |> assign(:page_title, word_set.name)}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    _word_set = socket.assigns.word_set

    {_word_set, words_result} = WordSets.get_word_set_with_words_paginated(socket.assigns.word_set.id, page: page, per_page: @per_page)

    {:noreply,
     socket
     |> assign(:words, words_result.words)
     |> assign(:page, page)}
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

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end
  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helper for template
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
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
                      data-confirm={gettext("Delete this practice test? You'll need to recreate it to take it again.")}
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
                    {gettext("Create a practice test to study these words with customizable question types.")}
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
            <h2 class="text-lg font-semibold text-base-content mb-4">
              {gettext("Words")}
            </h2>

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
      </div>
    </Layouts.app>
    """
  end
end
