defmodule MedoruWeb.WordBookLive.Present do
  @moduledoc """
  Public, read-only presentation ("slideshow") view of a word book.

  Anyone with the link can view: the UUID acts as an unguessable
  capability. Renders a page-flip flipbook (StPageFlip via the
  `WordBookPresent` hook) with one card face per page and a cover page,
  plus a print-friendly view showing every card front and back.

  Uses the stripped `Layouts.present` layout (no app nav/sidebar).
  """

  use MedoruWeb, :live_view

  alias Medoru.Learning.WordBooks
  alias MedoruWeb.WordBookCard

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case WordBooks.get_public_word_book(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Word book not found."))
         |> push_navigate(to: ~p"/")}

      word_book ->
        current_user = socket.assigns.current_scope[:current_user]

        {:noreply,
         socket
         |> assign(:page_title, word_book.title)
         |> assign(:word_book, word_book)
         |> assign(:author_name, author_name(word_book.user))
         |> assign(:is_owner?, !is_nil(current_user) && current_user.id == word_book.user_id)
         |> assign(:cover_image_path, cover_path(word_book.cover_image))
         |> assign(
           :present_url,
           "#{MedoruWeb.Endpoint.url()}#{~p"/word-books/#{word_book.id}"}"
         )}
    end
  end

  defp author_name(nil), do: nil
  defp author_name(%{profile: %{display_name: name}}) when name not in [nil, ""], do: name
  defp author_name(%{name: name}) when name not in [nil, ""], do: name
  defp author_name(_), do: nil

  defp cover_path(nil), do: nil
  defp cover_path(""), do: nil

  defp cover_path(cover_image) do
    WordBooks.cover_options()
    |> Enum.find_value(fn {key, _label, path} -> if key == cover_image, do: path end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.present flash={@flash}>
      <div
        id="word-book-present"
        class="wb-present"
        data-theme={@word_book.theme}
        data-card-shape={@word_book.card_shape || "rectangle"}
        phx-hook="WordBookPresent"
      >
        <header class="wb-present-header no-print">
          <div class="min-w-0">
            <h1 class="text-base sm:text-lg font-bold text-base-content truncate">
              {@word_book.title}
            </h1>
            <p :if={@author_name} class="text-xs text-secondary truncate">
              {@author_name}
            </p>
          </div>
          <div class="flex items-center gap-1 sm:gap-2 shrink-0">
            <.link
              :if={@is_owner?}
              navigate={~p"/words/books/#{@word_book.id}"}
              class="btn btn-sm btn-ghost px-2 sm:px-3"
              title={gettext("Back to book")}
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Back to book")}</span>
            </.link>
            <button
              id="wb-print-btn"
              type="button"
              class="btn btn-sm btn-ghost px-2 sm:px-3"
              title={gettext("Print")}
            >
              <.icon name="hero-printer" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Print")}</span>
            </button>
            <button
              id="wb-copy-link"
              type="button"
              phx-hook="CopyToClipboard"
              data-text={@present_url}
              class="btn btn-sm btn-ghost px-2 sm:px-3"
              title={gettext("Copy link")}
            >
              <.icon name="hero-link" class="w-4 h-4" />
              <span class="hidden sm:inline">{gettext("Copy link")}</span>
            </button>
          </div>
        </header>

        <div class="wb-flipbook-viewport no-print">
          <button
            id="wb-prev-btn"
            type="button"
            class="wb-nav-btn wb-nav-prev no-print"
            aria-label={gettext("Previous page")}
          >
            <.icon name="hero-chevron-left" class="w-6 h-6" />
          </button>
          <div id="word-book-flipbook" class="wb-flipbook">
            <div class="wb-page wb-cover-page">
              <div
                class="h-full w-full relative flex flex-col items-center justify-between p-8 text-center bg-base-100 text-base-content border border-base-300 overflow-hidden"
                style={cover_background_style(@cover_image_path)}
              >
                <div class="absolute inset-0 bg-gradient-to-t from-base-300/70 via-transparent to-base-300/20 pointer-events-none">
                </div>
                <h1 class="relative text-2xl sm:text-3xl font-bold text-base-content drop-shadow-sm line-clamp-4">
                  {@word_book.title}
                </h1>
                <%= if @cover_image_path do %>
                  <div></div>
                <% else %>
                  <% first_word = @word_book.word_book_words |> List.first() %>
                  <div
                    :if={first_word && first_word.word.text}
                    class="relative font-japanese text-6xl font-medium text-base-content drop-shadow-sm"
                  >
                    {first_word.word.text}
                  </div>
                <% end %>
                <div class="relative">
                  <p :if={@author_name} class="text-sm text-base-content/80">
                    {@author_name}
                  </p>
                  <p class="text-xs text-base-content/60">
                    {@word_book.word_count} {ngettext("card", "cards", @word_book.word_count)}
                  </p>
                </div>
              </div>
            </div>

            <%= for wbw <- @word_book.word_book_words do %>
              <div class="wb-page">
                <WordBookCard.face
                  id={"present-card-#{wbw.word_id}-front"}
                  word={wbw.word}
                  config={@word_book.front_config || %{}}
                  card_shape={@word_book.card_shape || "rectangle"}
                  background={@word_book.front_background}
                  custom_text={@word_book.custom_text}
                />
              </div>
              <div class="wb-page">
                <WordBookCard.face
                  id={"present-card-#{wbw.word_id}-back"}
                  word={wbw.word}
                  config={@word_book.back_config || %{}}
                  card_shape={@word_book.card_shape || "rectangle"}
                  background={@word_book.back_background}
                  custom_text={@word_book.custom_text}
                />
              </div>
            <% end %>
          </div>
          <button
            id="wb-next-btn"
            type="button"
            class="wb-nav-btn wb-nav-next no-print"
            aria-label={gettext("Next page")}
          >
            <.icon name="hero-chevron-right" class="w-6 h-6" />
          </button>
        </div>

        <%!-- Print view: every card front and back as separate printable blocks.
             Inherits the book theme: preset background SVGs are transparent
             patterns designed to show over the themed base color. --%>
        <div class="wb-print">
          <div class="wb-print-page wb-print-cover">
            <%= if @cover_image_path do %>
              <img class="wb-print-cover-bg" src={@cover_image_path} alt="" loading="eager" />
            <% end %>
            <div class="wb-print-cover-content">
              <h1>{@word_book.title}</h1>
              <p :if={@author_name}>{@author_name}</p>
            </div>
          </div>
          <%= for wbw <- @word_book.word_book_words do %>
            <div class="wb-print-page">
              <WordBookCard.face
                id={"print-card-#{wbw.word_id}-front"}
                word={wbw.word}
                config={@word_book.front_config || %{}}
                card_shape={@word_book.card_shape || "rectangle"}
                background={@word_book.front_background}
                custom_text={@word_book.custom_text}
                eager_images
              />
            </div>
            <div class="wb-print-page">
              <WordBookCard.face
                id={"print-card-#{wbw.word_id}-back"}
                word={wbw.word}
                config={@word_book.back_config || %{}}
                card_shape={@word_book.card_shape || "rectangle"}
                background={@word_book.back_background}
                custom_text={@word_book.custom_text}
                eager_images
              />
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.present>
    """
  end

  defp cover_background_style(nil), do: nil
  defp cover_background_style(path), do: "background-image: url('#{path}');"
end
