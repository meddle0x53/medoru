defmodule MedoruWeb.Admin.WordLive.Index do
  @moduledoc """
  Admin interface for listing and managing words.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "index/*"

  @per_page 30

  @impl true
  def render(assigns) do
    ~H"""
    {index(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page =
      case Integer.parse(params["page"] || "1") do
        {n, _} when n > 0 -> n
        _ -> 1
      end

    difficulty_filter = params["difficulty"]
    search = params["search"]
    sort_by = parse_sort_by(params["sort_by"])
    sort_order = parse_sort_order(params["sort_order"])

    difficulty =
      if difficulty_filter && difficulty_filter != "" do
        String.to_integer(difficulty_filter)
      else
        nil
      end

    result =
      Content.list_words_paginated(
        page: page,
        per_page: @per_page,
        search: search,
        difficulty: difficulty,
        sort_by: sort_by,
        sort_order: sort_order
      )

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Words"))
     |> assign(:words, result.words)
     |> assign(:page, result.current_page)
     |> assign(:total_pages, result.total_pages)
     |> assign(:total_count, result.total_count)
     |> assign(:difficulty_filter, difficulty_filter)
     |> assign(:search, search)
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:select_mode, false)
     |> assign(:selected, MapSet.new())}
  end

  @impl true
  def handle_event("filter_difficulty", %{"difficulty" => difficulty}, socket) do
    diff_param =
      case Integer.parse(difficulty) do
        {n, _} when n in 1..5 -> n
        _ -> nil
      end

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/admin/words?#{%{difficulty: diff_param, search: socket.assigns.search, sort_by: socket.assigns.sort_by, sort_order: socket.assigns.sort_order}}"
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/admin/words?#{%{difficulty: socket.assigns.difficulty_filter, search: search_param, sort_by: socket.assigns.sort_by, sort_order: socket.assigns.sort_order}}"
     )}
  end

  @impl true
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by_atom = parse_sort_by(sort_by)

    sort_order =
      if socket.assigns.sort_by == sort_by_atom do
        toggle_order(socket.assigns.sort_order)
      else
        default_order(sort_by_atom)
      end

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/admin/words?#{%{difficulty: socket.assigns.difficulty_filter, search: socket.assigns.search, sort_by: sort_by_atom, sort_order: sort_order}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/words")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    word = Content.get_word!(id)

    case Content.delete_word(word) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word deleted successfully."))
         |> push_patch(to: ~p"/admin/words")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete word. It may be in use."))}
    end
  end

  @impl true
  def handle_event("toggle_select_mode", _, socket) do
    select_mode = !socket.assigns.select_mode

    {:noreply,
     socket
     |> assign(:select_mode, select_mode)
     |> assign(:selected, MapSet.new())}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id) do
        MapSet.delete(socket.assigns.selected, id)
      else
        MapSet.put(socket.assigns.selected, id)
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  @impl true
  def handle_event("select_page", _, socket) do
    page_ids = Enum.map(socket.assigns.words, & &1.id)
    all_selected? = Enum.all?(page_ids, &MapSet.member?(socket.assigns.selected, &1))

    selected =
      if all_selected? do
        Enum.reduce(page_ids, socket.assigns.selected, &MapSet.delete(&2, &1))
      else
        Enum.reduce(page_ids, socket.assigns.selected, &MapSet.put(&2, &1))
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  @impl true
  def handle_event("delete_selected", _, socket) do
    ids = MapSet.to_list(socket.assigns.selected)

    case Content.delete_words(ids) do
      {:ok, count} ->
        # Stay on the current page if it still exists, otherwise fall back
        # to the new last page.
        totals =
          Content.list_words_paginated(
            page: 1,
            per_page: 1,
            search: socket.assigns.search,
            difficulty:
              case socket.assigns.difficulty_filter do
                nil -> nil
                "" -> nil
                d -> String.to_integer(d)
              end
          )

        target_page = min(socket.assigns.page, totals.total_pages)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Deleted %{count} words.", count: count))
         |> assign(:select_mode, false)
         |> assign(:selected, MapSet.new())
         |> push_patch(
           to:
             ~p"/admin/words?#{%{page: target_page, difficulty: socket.assigns.difficulty_filter, search: socket.assigns.search, sort_by: socket.assigns.sort_by, sort_order: socket.assigns.sort_order}}"
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete some words. They may be in use."))
         |> assign(:select_mode, false)
         |> assign(:selected, MapSet.new())}
    end
  end

  defp difficulty_badge_color(5), do: "badge-success"
  defp difficulty_badge_color(4), do: "badge-info"
  defp difficulty_badge_color(3), do: "badge-warning"
  defp difficulty_badge_color(2), do: "badge-error"
  defp difficulty_badge_color(1), do: "badge-secondary"
  defp difficulty_badge_color(_), do: "badge-ghost"

  defp parse_sort_by(nil), do: :usage_frequency

  defp parse_sort_by(sort_by) when is_binary(sort_by) do
    case sort_by do
      "text" -> :text
      "reading" -> :reading
      "meaning" -> :meaning
      "difficulty" -> :difficulty
      "word_type" -> :word_type
      "inserted_at" -> :inserted_at
      "usage_frequency" -> :usage_frequency
      _ -> :usage_frequency
    end
  end

  defp parse_sort_by(_), do: :usage_frequency

  defp parse_sort_order(nil), do: :asc
  defp parse_sort_order("asc"), do: :asc
  defp parse_sort_order("desc"), do: :desc
  defp parse_sort_order(_), do: :asc

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp default_order(:usage_frequency), do: :asc
  defp default_order(:difficulty), do: :desc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :asc

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
