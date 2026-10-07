defmodule MedoruWeb.WordSetLive.Index do
  @moduledoc """
  LiveView for listing user's word sets with pagination, search, and sorting.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordSets

  @per_page 20

  @word_types ~w(noun verb adjective adverb particle pronoun counter expression other)
  @levels [1, 2, 3, 4, 5]
  @default_learned_n 55

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    {:ok,
     socket
     |> assign(:page_title, gettext("My Word Sets"))
     |> assign(:search, nil)
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_order, :desc)
     |> assign_generate_defaults()
     |> load_word_sets(user.id, 1, nil, :inserted_at, :desc)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])
    search = parse_search(params["search"])
    sort_by = parse_sort_by(params["sort_by"])
    sort_order = parse_sort_order(params["sort_order"])

    user = socket.assigns.current_scope.current_user

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:search, search)
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> load_word_sets(user.id, page, search, sort_by, sort_order)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    params =
      [
        page: 1,
        search: query,
        sort_by: socket.assigns.sort_by,
        sort_order: socket.assigns.sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)

    {:noreply, push_patch(socket, to: ~p"/words/sets?#{params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    params =
      [
        page: 1,
        sort_by: socket.assigns.sort_by,
        sort_order: socket.assigns.sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    {:noreply, push_patch(socket, to: ~p"/words/sets?#{params}")}
  end

  @impl true
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by_atom = String.to_existing_atom(sort_by)

    # Toggle sort order if clicking same column
    sort_order =
      if socket.assigns.sort_by == sort_by_atom do
        toggle_order(socket.assigns.sort_order)
      else
        default_order(sort_by_atom)
      end

    params =
      [
        page: 1,
        search: socket.assigns.search,
        sort_by: sort_by,
        sort_order: sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)

    {:noreply, push_patch(socket, to: ~p"/words/sets?#{params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user
    word_set = WordSets.get_word_set!(id)

    # Ensure user owns this word set
    if word_set.user_id == user.id do
      case WordSets.delete_word_set(word_set) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Word set deleted successfully."))
           |> load_word_sets(
             user.id,
             socket.assigns.page,
             socket.assigns.search,
             socket.assigns.sort_by,
             socket.assigns.sort_order
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete word set."))}
      end
    else
      {:noreply,
       put_flash(socket, :error, gettext("You don't have permission to delete this word set."))}
    end
  end

  @impl true
  def handle_event("open_generate_modal", _params, socket) do
    {:noreply,
     socket
     |> assign_generate_defaults()
     |> assign(:generate_modal_open, true)}
  end

  @impl true
  def handle_event("close_generate_modal", _params, socket) do
    {:noreply, assign(socket, :generate_modal_open, false)}
  end

  @impl true
  def handle_event("validate_generate", params, socket) do
    {:noreply, apply_generate_params(socket, params)}
  end

  @impl true
  def handle_event("create_from_learned", params, socket) do
    socket = apply_generate_params(socket, params)
    user = socket.assigns.current_scope.current_user

    case WordSets.create_word_set_from_learned_words(user, %{
           name: socket.assigns.gen_name,
           n: socket.assigns.gen_n,
           word_types: socket.assigns.gen_word_types,
           levels: socket.assigns.gen_levels
         }) do
      {:ok, word_set} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word set created"))
         |> push_navigate(to: ~p"/words/sets/#{word_set.id}")}

      {:error, :no_matching_words} ->
        {:noreply,
         put_flash(socket, :error, gettext("No learned words match the selected filters."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to create word set."))}
    end
  end

  defp assign_generate_defaults(socket) do
    socket
    |> assign(:generate_modal_open, false)
    |> assign(:word_types, @word_types)
    |> assign(:levels, @levels)
    |> assign(:gen_name, gettext("Learned Words — %{date}", date: Date.utc_today()))
    |> assign(:gen_n, @default_learned_n)
    |> assign(:gen_word_types, @word_types)
    |> assign(:gen_levels, @levels)
    |> refresh_generate_counts()
  end

  defp apply_generate_params(socket, params) do
    p = params["generate"] || params

    n =
      case Integer.parse(to_string(p["n"] || "")) do
        {int, _} -> int
        :error -> 0
      end

    socket
    |> assign(:gen_name, to_string(p["name"] || ""))
    |> assign(:gen_n, n)
    |> assign(:gen_word_types, List.wrap(p["word_types"]))
    |> assign(
      :gen_levels,
      List.wrap(p["levels"]) |> Enum.map(&to_level/1) |> Enum.reject(&is_nil/1)
    )
    |> refresh_generate_counts()
  end

  defp refresh_generate_counts(socket) do
    user = socket.assigns.current_scope.current_user

    matching =
      WordSets.count_learned_words_matching(
        user.id,
        socket.assigns.gen_word_types,
        socket.assigns.gen_levels
      )

    max_n = min(@default_learned_n, matching)

    socket
    |> assign(:gen_matching, matching)
    |> assign(:gen_max_n, max_n)
    |> assign(
      :gen_valid?,
      matching > 0 and socket.assigns.gen_n >= 1 and socket.assigns.gen_n <= max_n
    )
  end

  defp to_level(level) when is_integer(level) and level in 1..5, do: level

  defp to_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {int, _} when int in 1..5 -> int
      _ -> nil
    end
  end

  defp to_level(_), do: nil

  defp humanize_word_type("noun"), do: gettext("Noun")
  defp humanize_word_type("verb"), do: gettext("Verb")
  defp humanize_word_type("adjective"), do: gettext("Adjective")
  defp humanize_word_type("adverb"), do: gettext("Adverb")
  defp humanize_word_type("particle"), do: gettext("Particle")
  defp humanize_word_type("pronoun"), do: gettext("Pronoun")
  defp humanize_word_type("counter"), do: gettext("Counter")
  defp humanize_word_type("expression"), do: gettext("Expression")
  defp humanize_word_type("other"), do: gettext("Other")
  defp humanize_word_type(type), do: type |> String.capitalize()

  defp load_word_sets(socket, user_id, page, search, sort_by, sort_order) do
    result =
      WordSets.list_user_word_sets(user_id,
        page: page,
        per_page: @per_page,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order
      )

    socket
    |> assign(:word_sets, result.word_sets)
    |> assign(:total_count, result.total_count)
    |> assign(:total_pages, result.total_pages)
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

  defp parse_search(nil), do: nil
  defp parse_search(""), do: nil
  defp parse_search(search), do: String.trim(search)

  defp parse_sort_by(nil), do: :inserted_at
  defp parse_sort_by("name"), do: :name
  defp parse_sort_by("inserted_at"), do: :inserted_at
  defp parse_sort_by(_), do: :inserted_at

  defp parse_sort_order(nil), do: :desc
  defp parse_sort_order("asc"), do: :asc
  defp parse_sort_order("desc"), do: :desc
  defp parse_sort_order(_), do: :desc

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp default_order(:name), do: :asc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :desc

  # Helper for templates
  def page_link_params(search, sort_by, sort_order, page) do
    params =
      [
        page: page,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)

    params
  end

  def sort_link_params(current_sort_by, current_sort_order, search, sort_by) do
    sort_order =
      if current_sort_by == sort_by do
        toggle_order(current_sort_order)
      else
        default_order(sort_by)
      end

    params =
      [
        page: 1,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)

    params
  end

  def sort_indicator(sort_by, sort_order, column) do
    if sort_by == column do
      case sort_order do
        :asc -> "↑"
        :desc -> "↓"
        _ -> ""
      end
    else
      ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-3xl font-bold text-base-content">{gettext("My Word Sets")}</h1>
            <p class="text-secondary mt-2">
              {gettext("Create personalized collections of words for focused study.")}
            </p>
          </div>
          <div class="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
            <button
              phx-click="open_generate_modal"
              class="inline-flex items-center justify-center gap-2 px-4 py-2 btn-outline border border-base-300 text-base-content hover:bg-base-200 rounded-lg font-medium transition-colors w-full sm:w-auto"
            >
              <.icon name="hero-clock" class="w-5 h-5" />
              {gettext("From Learned Words")}
            </button>
            <.link
              navigate={~p"/words/sets/new"}
              class="inline-flex items-center justify-center gap-2 px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors w-full sm:w-auto"
            >
              <.icon name="hero-plus" class="w-5 h-5" />
              {gettext("New Word Set")}
            </.link>
          </div>
        </div>

        <%!-- Search and Sort Controls --%>
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <%!-- Search --%>
          <form phx-submit="search" class="flex-1">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-secondary"
              />
              <input
                type="text"
                name="search[query]"
                value={@search}
                placeholder={gettext("Search word sets...")}
                class="w-full pl-10 pr-10 py-2 bg-base-100 border border-base-300 rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
              />
              <%= if @search && @search != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-secondary hover:text-base-content"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              <% end %>
            </div>
          </form>

          <%!-- Sort Controls --%>
          <div class="flex gap-2">
            <button
              phx-click="sort"
              phx-value-sort_by="name"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                if(@sort_by == :name,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content hover:bg-base-300"
                )
              ]}
            >
              {gettext("Name")} {sort_indicator(@sort_by, @sort_order, :name)}
            </button>
            <button
              phx-click="sort"
              phx-value-sort_by="inserted_at"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                if(@sort_by == :inserted_at,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content hover:bg-base-300"
                )
              ]}
            >
              {gettext("Created")} {sort_indicator(@sort_by, @sort_order, :inserted_at)}
            </button>
          </div>
        </div>

        <%!-- Word Sets List --%>
        <%= if length(@word_sets) == 0 do %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body text-center py-16">
              <.icon name="hero-folder-open" class="w-16 h-16 mx-auto text-secondary mb-4" />
              <h3 class="text-xl font-medium text-base-content mb-2">
                {gettext("No word sets yet")}
              </h3>
              <p class="text-secondary mb-6">
                {gettext("Create your first word set to start organizing words for study.")}
              </p>
              <.link
                navigate={~p"/words/sets/new"}
                class="inline-flex items-center gap-2 px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors mx-auto"
              >
                <.icon name="hero-plus" class="w-5 h-5" />
                {gettext("Create Word Set")}
              </.link>
            </div>
          </div>
        <% else %>
          <div class="grid gap-4">
            <%= for word_set <- @word_sets do %>
              <div class="card bg-base-100 border border-base-300 hover:border-primary/50 transition-colors">
                <div class="card-body p-4 sm:p-6">
                  <div class="flex flex-col sm:flex-row sm:items-center gap-4">
                    <%!-- Word Set Info --%>
                    <div class="flex-1 min-w-0">
                      <.link
                        navigate={~p"/words/sets/#{word_set.id}"}
                        class="text-lg font-semibold text-base-content hover:text-primary transition-colors"
                      >
                        {word_set.name}
                      </.link>
                      <%= if word_set.description && word_set.description != "" do %>
                        <p class="text-secondary text-sm mt-1 line-clamp-1">{word_set.description}</p>
                      <% end %>
                      <div class="flex flex-wrap items-center gap-x-4 gap-y-1 mt-2 text-sm text-secondary">
                        <span class="inline-flex items-center gap-1 whitespace-nowrap">
                          <.icon name="hero-book-open" class="w-4 h-4 shrink-0" />
                          {word_set.word_count} {ngettext("word", "words", word_set.word_count)}
                        </span>
                        <span class="inline-flex items-center gap-1 whitespace-nowrap">
                          <.icon name="hero-calendar" class="w-4 h-4 shrink-0" />
                          <span class="whitespace-nowrap">
                            {Calendar.strftime(word_set.inserted_at, "%b %d, %Y")}
                          </span>
                        </span>
                        <%= if word_set.practice_test_id do %>
                          <span class="inline-flex items-center gap-1 whitespace-nowrap text-success">
                            <.icon name="hero-check-circle" class="w-4 h-4 shrink-0" />
                            {gettext("Practice test ready")}
                          </span>
                        <% end %>
                      </div>
                    </div>

                    <%!-- Actions --%>
                    <div class="flex items-center gap-2 shrink-0">
                      <.link
                        navigate={~p"/words/sets/#{word_set.id}"}
                        class="btn btn-sm btn-ghost"
                      >
                        <.icon name="hero-eye" class="w-4 h-4" />
                        {gettext("View")}
                      </.link>
                      <.link
                        navigate={~p"/words/sets/#{word_set.id}/edit"}
                        class="btn btn-sm btn-ghost"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                        {gettext("Edit")}
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={word_set.id}
                        data-confirm={
                          gettext(
                            "Are you sure you want to delete this word set? This action cannot be undone."
                          )
                        }
                        class="btn btn-sm btn-ghost text-error"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                        {gettext("Delete")}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Pagination --%>
          <%= if @total_pages > 1 do %>
            <div class="flex justify-center gap-2 mt-8">
              <%= if @page > 1 do %>
                <.link
                  navigate={
                    ~p"/words/sets?#{page_link_params(@search, @sort_by, @sort_order, @page - 1)}"
                  }
                  class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-base-content transition-colors"
                >
                  <.icon name="hero-chevron-left" class="w-5 h-5" />
                </.link>
              <% end %>

              <span class="px-4 py-2 bg-base-100 border border-base-300 rounded-lg text-base-content">
                {@page} / {@total_pages}
              </span>

              <%= if @page < @total_pages do %>
                <.link
                  navigate={
                    ~p"/words/sets?#{page_link_params(@search, @sort_by, @sort_order, @page + 1)}"
                  }
                  class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-base-content transition-colors"
                >
                  <.icon name="hero-chevron-right" class="w-5 h-5" />
                </.link>
              <% end %>
            </div>
          <% end %>
        <% end %>

        <%!-- Generate From Learned Words Modal --%>
        <%= if @generate_modal_open do %>
          <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <div class="bg-base-100 rounded-2xl max-w-md w-full max-h-[80vh] overflow-y-auto p-6">
              <h2 class="text-xl font-bold text-base-content mb-4">
                {gettext("Word Set from Learned Words")}
              </h2>

              <form phx-change="validate_generate" phx-submit="create_from_learned">
                <div class="mb-4">
                  <label class="block text-sm font-medium text-base-content mb-1" for="generate-name">
                    {gettext("Name")}
                  </label>
                  <input
                    type="text"
                    id="generate-name"
                    name="generate[name]"
                    value={@gen_name}
                    class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-base-content focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  />
                </div>

                <div class="mb-4">
                  <label class="block text-sm font-medium text-base-content mb-1" for="generate-n">
                    {gettext("Number of words (max %{max})", max: @gen_max_n)}
                  </label>
                  <input
                    type="number"
                    id="generate-n"
                    name="generate[n]"
                    value={@gen_n}
                    min="1"
                    max={@gen_max_n}
                    class="w-full px-3 py-2 bg-base-100 border border-base-300 rounded-lg text-base-content focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                  />
                  <p class="text-sm text-secondary mt-1">
                    {ngettext("%{count} word available", "%{count} words available", @gen_matching,
                      count: @gen_matching
                    )}
                  </p>
                </div>

                <div class="mb-4">
                  <span class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Word types")}
                  </span>
                  <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    <%= for type <- @word_types do %>
                      <label class="flex items-center gap-2 text-sm text-base-content cursor-pointer">
                        <input
                          type="checkbox"
                          name="generate[word_types][]"
                          value={type}
                          checked={type in @gen_word_types}
                          class="checkbox checkbox-sm checkbox-primary"
                        />
                        {humanize_word_type(type)}
                      </label>
                    <% end %>
                  </div>
                </div>

                <div class="mb-6">
                  <span class="block text-sm font-medium text-base-content mb-2">
                    {gettext("JLPT levels")}
                  </span>
                  <div class="flex flex-wrap gap-2">
                    <%= for level <- @levels do %>
                      <label class="flex items-center gap-2 text-sm text-base-content cursor-pointer">
                        <input
                          type="checkbox"
                          name="generate[levels][]"
                          value={level}
                          checked={level in @gen_levels}
                          class="checkbox checkbox-sm checkbox-primary"
                        />
                        {"N#{level}"}
                      </label>
                    <% end %>
                  </div>
                </div>

                <div class="flex flex-col sm:flex-row gap-2">
                  <button
                    type="button"
                    phx-click="close_generate_modal"
                    class="px-4 py-2 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium transition-colors w-full sm:w-auto"
                  >
                    {gettext("Cancel")}
                  </button>
                  <button
                    type="submit"
                    disabled={not @gen_valid?}
                    class="px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors w-full sm:w-auto disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {gettext("Create")}
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
