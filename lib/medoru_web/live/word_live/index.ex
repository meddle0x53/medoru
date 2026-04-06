defmodule MedoruWeb.WordLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "index.html"

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    # Get learned word IDs if user is logged in
    learned_word_ids =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Learning.list_learned_word_ids(socket.assigns.current_scope.current_user.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:difficulty, 5)
     |> assign(:locale, locale)
     |> assign(:learned_word_ids, learned_word_ids)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    page = parse_page(params["page"])
    search = parse_search(params["search"])
    sort_by = parse_sort_by(params["sort_by"])
    sort_order = parse_sort_order(params["sort_order"])
    learned_filter = parse_learned_filter(params["learned_filter"])
    word_type = parse_word_type(params["word_type"])

    # Get user_id for learned filter
    user_id =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        socket.assigns.current_scope.current_user.id
      else
        nil
      end

    result =
      Content.list_words_paginated(
        page: page,
        per_page: @per_page,
        difficulty: difficulty,
        word_type: word_type,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order,
        learned_filter: learned_filter,
        user_id: user_id
      )

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:page, page)
     |> assign(:search, search)
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:learned_filter, learned_filter)
     |> assign(:word_type, word_type)
     |> assign(:words, result.words)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, page_title(difficulty, search))}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    params = [
      difficulty: socket.assigns.difficulty,
      word_type: socket.assigns.word_type,
      search: query,
      page: 1,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    ]

    {:noreply, push_patch(socket, to: ~p"/words?#{params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    params = [
      difficulty: socket.assigns.difficulty,
      word_type: socket.assigns.word_type,
      page: 1,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    ]

    {:noreply, push_patch(socket, to: ~p"/words?#{params}")}
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
        difficulty: socket.assigns.difficulty,
        word_type: socket.assigns.word_type,
        search: socket.assigns.search,
        page: 1,
        sort_by: sort_by,
        sort_order: sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    {:noreply, push_patch(socket, to: ~p"/words?#{params}")}
  end

  @impl true
  def handle_event("filter_word_type", %{"word_type" => word_type}, socket) do
    word_type = if word_type == "", do: nil, else: word_type

    params = [
      difficulty: socket.assigns.difficulty,
      word_type: word_type,
      search: socket.assigns.search,
      page: 1,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    ]

    {:noreply, push_patch(socket, to: ~p"/words?#{params}")}
  end

  defp page_title(difficulty, nil), do: gettext("JLPT N%{level} Vocabulary", level: difficulty)
  defp page_title(difficulty, ""), do: gettext("JLPT N%{level} Vocabulary", level: difficulty)
  defp page_title(_difficulty, search), do: gettext("Search: %{query}", query: search)

  defp parse_difficulty(nil), do: nil

  defp parse_difficulty(difficulty) when is_binary(difficulty) do
    case Integer.parse(difficulty) do
      {n, _} when n in 1..5 -> n
      _ -> nil
    end
  end

  defp parse_difficulty(difficulty) when is_integer(difficulty) and difficulty in 1..5,
    do: difficulty

  defp parse_difficulty(_), do: nil

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

  defp parse_sort_by(nil), do: :usage_frequency

  defp parse_sort_by(sort_by) when is_binary(sort_by) do
    case sort_by do
      "text" -> :text
      "reading" -> :reading
      "meaning" -> :meaning
      "difficulty" -> :difficulty
      "word_type" -> :word_type
      "usage_frequency" -> :usage_frequency
      _ -> :usage_frequency
    end
  end

  defp parse_sort_by(_), do: :usage_frequency

  defp parse_sort_order(nil), do: :asc

  defp parse_sort_order(order) when is_binary(order) do
    case order do
      "asc" -> :asc
      "desc" -> :desc
      _ -> :desc
    end
  end

  defp parse_sort_order(_), do: :desc

  defp parse_learned_filter(nil), do: nil
  defp parse_learned_filter(""), do: nil

  defp parse_learned_filter(filter) when is_binary(filter) do
    case filter do
      "learned" -> :learned
      "unlearned" -> :unlearned
      _ -> nil
    end
  end

  defp parse_learned_filter(_), do: nil

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

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  # Learning order: sort_score combines frequency + complexity (ascending)
  # Single kanji → kanji+kana → 2 kanji → complex patterns
  defp default_order(:sort_score), do: :asc
  # Most common words first (ascending frequency)
  defp default_order(:usage_frequency), do: :asc
  # JLPT: Easiest first (N5=5 -> N1=1, so descending)
  defp default_order(:difficulty), do: :desc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :asc

  # Helper for template: generate page link params
  def page_link_params(assigns, page) do
    assigns = Map.new(assigns)

    [
      difficulty: Map.get(assigns, :difficulty),
      word_type: Map.get(assigns, :word_type),
      search: Map.get(assigns, :search),
      page: page,
      sort_by: Map.get(assigns, :sort_by),
      sort_order: Map.get(assigns, :sort_order),
      learned_filter: Map.get(assigns, :learned_filter)
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Helper for template: generate sort link params
  def sort_link_params(assigns, sort_by) do
    assigns = Map.new(assigns)
    current_sort_by = Map.get(assigns, :sort_by)
    current_sort_order = Map.get(assigns, :sort_order)

    sort_order =
      if current_sort_by == sort_by do
        toggle_order(current_sort_order)
      else
        default_order(sort_by)
      end

    [
      difficulty: Map.get(assigns, :difficulty),
      word_type: Map.get(assigns, :word_type),
      search: Map.get(assigns, :search),
      page: 1,
      sort_by: sort_by,
      sort_order: sort_order
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Helper for template: sort indicator
  def sort_indicator(assigns, column) do
    assigns = Map.new(assigns)

    if Map.get(assigns, :sort_by) == column do
      case Map.get(assigns, :sort_order) do
        :asc -> "↑"
        :desc -> "↓"
        _ -> ""
      end
    else
      ""
    end
  end

  # Helper for template: get localized word meaning
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end

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
end
