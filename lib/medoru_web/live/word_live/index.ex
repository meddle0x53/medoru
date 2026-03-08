defmodule MedoruWeb.WordLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @per_page 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :difficulty, 5)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    page = parse_page(params["page"])
    search = parse_search(params["search"])
    sort_by = parse_sort_by(params["sort_by"])
    sort_order = parse_sort_order(params["sort_order"])

    result =
      Content.list_words_paginated(
        page: page,
        per_page: @per_page,
        difficulty: difficulty,
        search: search,
        sort_by: sort_by,
        sort_order: sort_order
      )

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:page, page)
     |> assign(:search, search)
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:words, result.words)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, page_title(difficulty, search))}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    params = [
      difficulty: socket.assigns.difficulty,
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
        search: socket.assigns.search,
        page: 1,
        sort_by: sort_by,
        sort_order: sort_order
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    {:noreply, push_patch(socket, to: ~p"/words?#{params}")}
  end

  defp page_title(difficulty, nil), do: "JLPT N#{difficulty} Vocabulary"
  defp page_title(difficulty, ""), do: "JLPT N#{difficulty} Vocabulary"
  defp page_title(_difficulty, search), do: "Search: #{search}"

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
      "inserted_at" -> :inserted_at
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

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  # Easiest first: N5 (level 5) -> N1 (level 1) = descending order
  # Learning order: Most common words first (ascending frequency)
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
      search: Map.get(assigns, :search),
      page: page,
      sort_by: Map.get(assigns, :sort_by),
      sort_order: Map.get(assigns, :sort_order)
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
end
