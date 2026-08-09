defmodule MedoruWeb.WordBookLive.Show do
  @moduledoc """
  LiveView for viewing a word book.

  Opens on a book-cover page (preset cover or a generated default cover).
  Clicking "Open" shows the vocabulary cards in a paginated grid with a
  cards-per-page selector (persisted on the book), prev/next navigation
  (URL page param), and left/right arrow keyboard navigation.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning.WordBooks
  alias Medoru.WhiteBoard
  alias MedoruWeb.WordBookCard

  @cards_per_page_options [1, 2, 4, 6]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:view_state, :cover)
     |> assign(:page, 1)
     |> assign(:total_pages, 1)
     |> assign(:words, [])
     |> assign(:cards_per_page_options, @cards_per_page_options)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    user = socket.assigns.current_scope.current_user
    word_book = WordBooks.get_user_word_book(user.id, id)

    if is_nil(word_book) do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to view this word book."))
       |> push_navigate(to: ~p"/words/books")}
    else
      socket =
        socket
        |> assign(:page_title, word_book.title)
        |> assign(:word_book, word_book)
        |> assign(:cards_per_page, normalize_cards_per_page(word_book.cards_per_page))
        |> assign(:cover_word, cover_word(word_book))

      socket =
        if socket.assigns.view_state == :open do
          load_page(socket, parse_page(params["page"]))
        else
          socket
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_book", _params, socket) do
    {:noreply,
     socket
     |> assign(:view_state, :open)
     |> load_page(socket.assigns.page)}
  end

  def handle_event("close_book", _params, socket) do
    {:noreply, assign(socket, :view_state, :cover)}
  end

  def handle_event("post_card_to_board", %{"word_id" => word_id}, socket) do
    word = Enum.find(socket.assigns.words, &(&1.id == word_id))
    user = socket.assigns.current_scope.current_user

    case word && WhiteBoard.create_word_card_post(user, socket.assigns.word_book, word) do
      {:ok, _post} ->
        {:noreply, put_flash(socket, :info, gettext("Card posted to your White Board."))}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not post the card."))}
    end
  end

  def handle_event("set_cards_per_page", %{"count" => count}, socket) do
    with {count, ""} <- Integer.parse(count),
         true <- count in @cards_per_page_options,
         {:ok, word_book} <-
           WordBooks.update_word_book(socket.assigns.word_book, %{"cards_per_page" => count}) do
      {:noreply,
       socket
       |> assign(:word_book, word_book)
       |> assign(:cards_per_page, count)
       |> push_patch(to: ~p"/words/books/#{word_book.id}?page=1")}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => key}, socket) do
    %{view_state: view_state, page: page, total_pages: total_pages} = socket.assigns

    case {view_state, key} do
      {:open, "ArrowRight"} when page < total_pages ->
        {:noreply, push_patch(socket, to: page_path(socket, page + 1))}

      {:open, "ArrowLeft"} when page > 1 ->
        {:noreply, push_patch(socket, to: page_path(socket, page - 1))}

      _ ->
        {:noreply, socket}
    end
  end

  defp load_page(socket, requested_page) do
    per_page = socket.assigns.cards_per_page
    {word_book, result} = fetch_page(socket.assigns.word_book.id, requested_page, per_page)

    page = min(requested_page, result.total_pages)

    result =
      if page != requested_page do
        {_book, result} = fetch_page(word_book.id, page, per_page)
        result
      else
        result
      end

    socket
    |> assign(:page, page)
    |> assign(:words, result.words)
    |> assign(:total_pages, result.total_pages)
  end

  defp fetch_page(word_book_id, page, per_page) do
    WordBooks.get_word_book_with_words_paginated(word_book_id, page: page, per_page: per_page)
  end

  defp page_path(socket, page) do
    ~p"/words/books/#{socket.assigns.word_book.id}?page=#{page}"
  end

  # First word of the book (preloaded in position order), used for the
  # generated default cover.
  defp cover_word(word_book) do
    case word_book.word_book_words do
      [first | _] -> first.word
      [] -> nil
    end
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp theme_attr(nil), do: nil
  defp theme_attr(""), do: nil
  defp theme_attr(theme), do: theme

  # Resolves a stored cover_image key to its static path, or nil.
  defp cover_path(nil), do: nil
  defp cover_path(""), do: nil

  defp cover_path(cover_image) do
    WordBooks.cover_options()
    |> Enum.find_value(fn {key, _label, path} -> if key == cover_image, do: path end)
  end

  defp plain_background_path do
    WordBooks.background_options()
    |> Enum.find_value(fn {key, _label, path} -> if key == "plain", do: path end)
  end

  # Width caps keep cards roughly the same physical size at every
  # cards-per-page setting instead of stretching to fill the page.
  # Square books get 1.5x wider columns so each square's side is
  # width + half of the width a rectangle-mode card would have.
  defp grid_class(count, "square"), do: square_grid_class(count)
  defp grid_class(count, _shape), do: rectangle_grid_class(count)

  defp rectangle_grid_class(1), do: "grid-cols-1 max-w-sm mx-auto"
  defp rectangle_grid_class(2), do: "grid-cols-1 sm:grid-cols-2 max-w-2xl mx-auto"
  defp rectangle_grid_class(4), do: "grid-cols-1 sm:grid-cols-2 max-w-3xl mx-auto"
  defp rectangle_grid_class(6), do: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 max-w-5xl mx-auto"
  defp rectangle_grid_class(_), do: rectangle_grid_class(6)

  defp square_grid_class(1), do: "grid-cols-1 max-w-xl mx-auto"
  defp square_grid_class(2), do: "grid-cols-1 sm:grid-cols-2 max-w-5xl mx-auto"
  defp square_grid_class(4), do: "grid-cols-1 sm:grid-cols-2 max-w-6xl mx-auto"
  defp square_grid_class(6), do: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 max-w-7xl mx-auto"
  defp square_grid_class(_), do: square_grid_class(6)

  # Books saved before some per-page options were removed may hold stale
  # values; coerce anything unsupported to the largest grid.
  defp normalize_cards_per_page(nil), do: 4
  defp normalize_cards_per_page(count) when count in @cards_per_page_options, do: count
  defp normalize_cards_per_page(_count), do: 6

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen" data-theme={theme_attr(@word_book.theme)}>
        <%= if @view_state == :cover do %>
          <.cover word_book={@word_book} cover_word={@cover_word} />
        <% else %>
          <.viewer
            word_book={@word_book}
            words={@words}
            page={@page}
            total_pages={@total_pages}
            cards_per_page={@cards_per_page}
            cards_per_page_options={@cards_per_page_options}
          />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :word_book, :any, required: true
  attr :cover_word, :any, default: nil

  defp cover(assigns) do
    assigns = assign(assigns, :cover_image_path, cover_path(assigns.word_book.cover_image))

    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <%!-- Header --%>
      <div class="mb-8 flex items-center justify-between gap-2">
        <.link
          navigate={~p"/words/books"}
          class="inline-flex items-center gap-1 text-secondary hover:text-primary text-sm transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" />
          <span class="hidden sm:inline">{gettext("Back to Word Books")}</span>
        </.link>
        <div class="flex items-center gap-1 sm:gap-2 shrink-0">
          <.link
            navigate={~p"/words/books/#{@word_book.id}/design"}
            class="btn btn-sm btn-ghost px-2 sm:px-3"
            title={gettext("Design")}
          >
            <.icon name="hero-paint-brush" class="w-4 h-4" />
            <span class="hidden sm:inline">{gettext("Design")}</span>
          </.link>
          <.link
            navigate={~p"/words/books/#{@word_book.id}/edit-words"}
            class="btn btn-sm btn-ghost px-2 sm:px-3"
            title={gettext("Edit Words")}
          >
            <.icon name="hero-pencil-square" class="w-4 h-4" />
            <span class="hidden sm:inline">{gettext("Edit Words")}</span>
          </.link>
        </div>
      </div>

      <%!-- Book cover (click to open) --%>
      <div class="max-w-md mx-auto">
        <div
          class={[
            "relative aspect-[3/4] rounded-2xl shadow-2xl overflow-hidden border border-base-300 bg-base-200 transition-transform duration-200",
            @word_book.word_count > 0 && "cursor-pointer hover:scale-[1.02] hover:shadow-primary/20"
          ]}
          phx-click={@word_book.word_count > 0 && "open_book"}
          title={@word_book.word_count > 0 && gettext("Click to open the book")}
        >
          <%= cond do %>
            <% @cover_image_path -> %>
              <img
                src={@cover_image_path}
                alt={@word_book.title}
                class="absolute inset-0 w-full h-full object-cover"
              />
            <% @cover_word && @cover_word.image_path -> %>
              <img
                src={@cover_word.image_path}
                alt={@cover_word.text}
                class="absolute inset-0 w-full h-full object-cover opacity-40"
              />
            <% true -> %>
              <div
                class="absolute inset-0 w-full h-full bg-base-200"
                style={"background-image: url('#{plain_background_path()}');"}
              >
              </div>
          <% end %>
          <div class="absolute inset-0 bg-gradient-to-t from-base-300/80 via-transparent to-base-300/30">
          </div>
          <div class="absolute inset-0 flex flex-col items-center justify-between p-8 text-center">
            <h1 class="text-3xl font-bold text-base-content drop-shadow-sm line-clamp-3">
              {@word_book.title}
            </h1>
            <%= if is_nil(@cover_image_path) && @cover_word do %>
              <div class="font-japanese text-6xl font-medium text-base-content drop-shadow-sm">
                {@cover_word.text}
              </div>
            <% else %>
              <div></div>
            <% end %>
            <p class="text-sm text-base-content/80">
              {@word_book.word_count} {ngettext("word", "words", @word_book.word_count)}
            </p>
          </div>
        </div>

        <%!-- Empty state --%>
        <div class="mt-8 text-center">
          <%= if @word_book.word_count == 0 do %>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body items-center text-center py-8">
                <.icon name="hero-rectangle-stack" class="w-10 h-10 text-secondary mb-2" />
                <p class="text-base-content font-medium">{gettext("This book has no words yet.")}</p>
                <p class="text-secondary text-sm">
                  {gettext("Add words before opening the book.")}
                </p>
                <.link
                  navigate={~p"/words/books/#{@word_book.id}/edit-words"}
                  class="btn btn-primary btn-sm mt-2"
                >
                  {gettext("Add Words")}
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :word_book, :any, required: true
  attr :words, :list, required: true
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :cards_per_page, :integer, required: true
  attr :cards_per_page_options, :list, required: true

  defp viewer(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6" phx-window-keydown="handle_key">
      <%!-- Persistent header (compact on mobile: icon-only buttons, text from sm up) --%>
      <div class="mb-6 flex flex-col gap-3">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <h1 class="text-lg sm:text-2xl font-bold text-base-content truncate">
              {@word_book.title}
            </h1>
            <p class="text-secondary text-xs sm:text-sm">
              {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
            </p>
          </div>
          <div class="flex items-center gap-1 sm:gap-2 shrink-0">
            <.link
              navigate={~p"/words/books/#{@word_book.id}/design"}
              class="btn btn-sm btn-ghost px-2 sm:px-3"
              title={gettext("Design")}
            >
              <.icon name="hero-paint-brush" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Design")}</span>
            </.link>
            <.link
              navigate={~p"/words/books/#{@word_book.id}/edit-words"}
              class="btn btn-sm btn-ghost px-2 sm:px-3"
              title={gettext("Edit Words")}
            >
              <.icon name="hero-pencil-square" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Edit Words")}</span>
            </.link>
            <button
              type="button"
              phx-click="close_book"
              class="btn btn-sm btn-outline px-2 sm:px-3"
              title={gettext("Close book")}
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Close book")}</span>
            </button>
          </div>
        </div>

        <div class="flex items-center justify-between gap-2">
          <%!-- Cards per page selector --%>
          <div class="join">
            <%= for count <- @cards_per_page_options do %>
              <button
                type="button"
                phx-click="set_cards_per_page"
                phx-value-count={count}
                class={[
                  "join-item btn btn-xs sm:btn-sm",
                  if(@cards_per_page == count, do: "btn-primary", else: "btn-ghost")
                ]}
              >
                {count}
              </button>
            <% end %>
          </div>

          <%!-- Prev / next --%>
          <div class="flex items-center gap-1 sm:gap-2 shrink-0">
            <%= if @page > 1 do %>
              <.link
                patch={~p"/words/books/#{@word_book.id}?page=#{@page - 1}"}
                class="btn btn-xs sm:btn-sm px-2 sm:px-3"
                title={gettext("Previous")}
              >
                <.icon name="hero-chevron-left" class="w-4 h-4" />
                <span class="hidden sm:inline">{gettext("Previous")}</span>
              </.link>
            <% else %>
              <button type="button" class="btn btn-xs sm:btn-sm px-2 sm:px-3" disabled>
                <.icon name="hero-chevron-left" class="w-4 h-4" />
                <span class="hidden sm:inline">{gettext("Previous")}</span>
              </button>
            <% end %>
            <%= if @page < @total_pages do %>
              <.link
                patch={~p"/words/books/#{@word_book.id}?page=#{@page + 1}"}
                class="btn btn-xs sm:btn-sm px-2 sm:px-3"
                title={gettext("Next")}
              >
                <span class="hidden sm:inline">{gettext("Next")}</span>
                <.icon name="hero-chevron-right" class="w-4 h-4" />
              </.link>
            <% else %>
              <button type="button" class="btn btn-xs sm:btn-sm px-2 sm:px-3" disabled>
                <span class="hidden sm:inline">{gettext("Next")}</span>
                <.icon name="hero-chevron-right" class="w-4 h-4" />
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Card grid (hook keeps every card on the page the same size) --%>
      <div
        id="word-book-card-grid"
        phx-hook="WordBookCards"
        data-card-shape={@word_book.card_shape || "rectangle"}
        class={["grid gap-4 sm:gap-6", grid_class(@cards_per_page, @word_book.card_shape)]}
      >
        <%= for word <- @words do %>
          <WordBookCard.card
            id={"card-#{word.id}"}
            word={word}
            front_config={@word_book.front_config || %{}}
            back_config={@word_book.back_config || %{}}
            card_shape={@word_book.card_shape || "rectangle"}
            front_background={@word_book.front_background}
            back_background={@word_book.back_background}
            custom_text={@word_book.custom_text}
            download={true}
            post={true}
          />
        <% end %>
      </div>
    </div>
    """
  end
end
