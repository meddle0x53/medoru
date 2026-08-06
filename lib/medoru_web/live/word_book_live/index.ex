defmodule MedoruWeb.WordBookLive.Index do
  @moduledoc """
  LiveView for listing user's word books with pagination, search, and sorting.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordBooks

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("My Word Books"))
     |> assign(:search, nil)
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_order, :desc)}
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
     |> load_word_books(user.id, page, search, sort_by, sort_order)}
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

    {:noreply, push_patch(socket, to: ~p"/words/books?#{params}")}
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

    {:noreply, push_patch(socket, to: ~p"/words/books?#{params}")}
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

    {:noreply, push_patch(socket, to: ~p"/words/books?#{params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user

    case WordBooks.get_user_word_book(user.id, id) do
      nil ->
        {:noreply,
         put_flash(socket, :error, gettext("You don't have permission to delete this word book."))}

      word_book ->
        case WordBooks.delete_word_book(word_book) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Word book deleted successfully."))
             |> load_word_books(
               user.id,
               socket.assigns.page,
               socket.assigns.search,
               socket.assigns.sort_by,
               socket.assigns.sort_order
             )}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to delete word book."))}
        end
    end
  end

  defp load_word_books(socket, user_id, page, search, sort_by, sort_order) do
    result =
      WordBooks.list_user_word_books(user_id,
        page: page,
        per_page: @per_page,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order
      )

    socket
    |> assign(:word_books, result.word_books)
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
  defp parse_sort_by("title"), do: :title
  defp parse_sort_by("inserted_at"), do: :inserted_at
  defp parse_sort_by(_), do: :inserted_at

  defp parse_sort_order(nil), do: :desc
  defp parse_sort_order("asc"), do: :asc
  defp parse_sort_order("desc"), do: :desc
  defp parse_sort_order(_), do: :desc

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp default_order(:title), do: :asc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :desc

  # Resolves a stored cover_image key to its static path, or nil for the default cover.
  def cover_path(nil), do: nil
  def cover_path(""), do: nil

  def cover_path(cover_image) do
    WordBooks.cover_options()
    |> Enum.find_value(fn {key, _label, path} -> if key == cover_image, do: path end)
  end

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
            <h1 class="text-3xl font-bold text-base-content">{gettext("My Word Books")}</h1>
            <p class="text-secondary mt-2">
              {gettext("Create vocabulary card collections for focused study.")}
            </p>
          </div>
          <.link
            navigate={~p"/words/books/new"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
          >
            <.icon name="hero-plus" class="w-5 h-5" />
            {gettext("New Word Book")}
          </.link>
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
                placeholder={gettext("Search word books...")}
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
              phx-value-sort_by="title"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                if(@sort_by == :title,
                  do: "bg-primary text-primary-content",
                  else: "bg-base-200 text-base-content hover:bg-base-300"
                )
              ]}
            >
              {gettext("Title")} {sort_indicator(@sort_by, @sort_order, :title)}
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

        <%!-- Word Books Grid --%>
        <%= if length(@word_books) == 0 do %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body text-center py-16">
              <.icon name="hero-book-open" class="w-16 h-16 mx-auto text-secondary mb-4" />
              <h3 class="text-xl font-medium text-base-content mb-2">
                {gettext("No word books yet")}
              </h3>
              <p class="text-secondary mb-6">
                {gettext("Create your first word book to start organizing vocabulary cards.")}
              </p>
              <.link
                navigate={~p"/words/books/new"}
                class="inline-flex items-center gap-2 px-4 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors mx-auto"
              >
                <.icon name="hero-plus" class="w-5 h-5" />
                {gettext("Create Word Book")}
              </.link>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for word_book <- @word_books do %>
              <div class="card bg-base-100 border border-base-300 hover:border-primary/50 transition-colors overflow-hidden">
                <%!-- Cover --%>
                <.link navigate={~p"/words/books/#{word_book}"} class="block">
                  <%= if cover_path(word_book.cover_image) do %>
                    <img
                      src={cover_path(word_book.cover_image)}
                      alt={word_book.title}
                      class="w-full h-32 object-cover"
                    />
                  <% else %>
                    <div class="w-full h-32 bg-base-200 flex items-center justify-center px-4">
                      <span class="text-lg font-semibold text-secondary text-center line-clamp-2">
                        {word_book.title}
                      </span>
                    </div>
                  <% end %>
                </.link>

                <div class="card-body p-4">
                  <%!-- Word Book Info --%>
                  <.link
                    navigate={~p"/words/books/#{word_book}"}
                    class="text-lg font-semibold text-base-content hover:text-primary transition-colors"
                  >
                    {word_book.title}
                  </.link>
                  <%= if word_book.description && word_book.description != "" do %>
                    <p class="text-secondary text-sm mt-1 line-clamp-1">{word_book.description}</p>
                  <% end %>
                  <div class="flex items-center gap-4 mt-2 text-sm text-secondary">
                    <span class="flex items-center gap-1">
                      <.icon name="hero-book-open" class="w-4 h-4" />
                      {word_book.word_count} {ngettext("word", "words", word_book.word_count)}
                    </span>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-calendar" class="w-4 h-4" />
                      {Calendar.strftime(word_book.inserted_at, "%b %d, %Y")}
                    </span>
                  </div>

                  <%!-- Actions --%>
                  <div class="flex flex-wrap items-center gap-2 mt-4">
                    <.link
                      navigate={~p"/words/books/#{word_book}"}
                      class="btn btn-sm btn-primary"
                    >
                      <.icon name="hero-book-open" class="w-4 h-4" />
                      {gettext("Open book")}
                    </.link>
                    <.link
                      navigate={~p"/words/books/#{word_book.id}/edit"}
                      class="btn btn-sm btn-ghost"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4" />
                      {gettext("Edit")}
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={word_book.id}
                      data-confirm={
                        gettext(
                          "Are you sure you want to delete this word book? This action cannot be undone."
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
            <% end %>
          </div>

          <%!-- Pagination --%>
          <%= if @total_pages > 1 do %>
            <div class="flex justify-center gap-2 mt-8">
              <%= if @page > 1 do %>
                <.link
                  navigate={
                    ~p"/words/books?#{page_link_params(@search, @sort_by, @sort_order, @page - 1)}"
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
                    ~p"/words/books?#{page_link_params(@search, @sort_by, @sort_order, @page + 1)}"
                  }
                  class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-base-content transition-colors"
                >
                  <.icon name="hero-chevron-right" class="w-5 h-5" />
                </.link>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
