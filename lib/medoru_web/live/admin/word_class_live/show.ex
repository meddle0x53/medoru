defmodule MedoruWeb.Admin.WordClassLive.Show do
  @moduledoc """
  Admin interface for viewing and managing words in a word class.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "show/*"

  @impl true
  def render(assigns) do
    ~H"""
    {show_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    word_class = Content.get_word_class_with_words!(params["id"])
    words_in_class = word_class.words

    {:noreply,
     socket
     |> assign(:page_title, word_class.display_name)
     |> assign(:word_class, word_class)
     |> assign(:words_in_class, words_in_class)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:word_stats, %{
       total_words: length(words_in_class),
       verbs: Enum.count(words_in_class, &(&1.word_type == :verb)),
       nouns: Enum.count(words_in_class, &(&1.word_type == :noun)),
       adjectives: Enum.count(words_in_class, &(&1.word_type == :adjective))
     })}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 1 do
        Content.search_words(query, limit: 10)
        |> Enum.reject(fn word ->
          Content.word_in_class?(word.id, socket.assigns.word_class.id)
        end)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("add_word", %{"word_id" => word_id}, socket) do
    word_class = socket.assigns.word_class

    case Content.add_word_to_class(word_id, word_class.id) do
      {:ok, _} ->
        _word = Content.get_word!(word_id)
        words_in_class = Content.list_words_in_class(word_class.id)

        {:noreply,
         socket
         |> assign(:words_in_class, words_in_class)
         |> assign(:search_query, "")
         |> assign(:search_results, [])
         |> assign(:word_stats, %{
           total_words: length(words_in_class),
           verbs: Enum.count(words_in_class, &(&1.word_type == :verb)),
           nouns: Enum.count(words_in_class, &(&1.word_type == :noun)),
           adjectives: Enum.count(words_in_class, &(&1.word_type == :adjective))
         })
         |> put_flash(:info, gettext("Word added to class"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to add word"))}
    end
  end

  @impl true
  def handle_event("remove_word", %{"word_id" => word_id}, socket) do
    word_class = socket.assigns.word_class

    case Content.remove_word_from_class(word_id, word_class.id) do
      {:ok, _} ->
        words_in_class = Content.list_words_in_class(word_class.id)

        {:noreply,
         socket
         |> assign(:words_in_class, words_in_class)
         |> assign(:word_stats, %{
           total_words: length(words_in_class),
           verbs: Enum.count(words_in_class, &(&1.word_type == :verb)),
           nouns: Enum.count(words_in_class, &(&1.word_type == :noun)),
           adjectives: Enum.count(words_in_class, &(&1.word_type == :adjective))
         })
         |> put_flash(:info, gettext("Word removed from class"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove word"))}
    end
  end
end
