defmodule MedoruWeb.LearnedWordsLive.Index do
  @moduledoc """
  LiveView for displaying a user's learned words.
  Reuses the same structure as WordLive.Index.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning
  alias Medoru.Content

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)
    english_mode? = user.learning_language == "english"

    # Get all learned word IDs for highlighting
    learned_word_ids = Learning.list_learned_word_ids_for_user(user)

    # Get learned words with pagination
    result =
      list_learned_words_paginated(user,
        page: 1,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:page, 1)
     |> assign(:english_mode?, english_mode?)
     |> assign(:words, result.words)
     |> assign(:learned_word_ids, learned_word_ids)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, gettext("%{name}'s Learned Words", name: user.name || user.email))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    user = socket.assigns.user

    result =
      list_learned_words_paginated(user,
        page: page,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:words, result.words)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)}
  end

  defp list_learned_words_paginated(user, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)

    # Get total count
    total_count = Learning.words_learned_count(user)

    # Get paginated words
    words =
      Learning.list_learned_words_for_user(user,
        limit: per_page,
        offset: (page - 1) * per_page
      )

    total_pages = ceil(total_count / per_page)

    %{
      words: words,
      total_count: total_count,
      total_pages: max(1, total_pages)
    }
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helper for template
  def page_link_params(_assigns, page) do
    [page: page]
  end

  # Helper for template
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end
end
