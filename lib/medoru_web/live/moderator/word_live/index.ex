defmodule MedoruWeb.Moderator.WordLive.Index do
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
        difficulty: difficulty
      )

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Words"))
     |> assign(:words, result.words)
     |> assign(:page, result.current_page)
     |> assign(:total_pages, result.total_pages)
     |> assign(:total_count, result.total_count)
     |> assign(:difficulty_filter, difficulty_filter)
     |> assign(:search, search)}
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
       to: ~p"/moderator/words?#{%{difficulty: diff_param, search: socket.assigns.search}}"
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/moderator/words?#{%{difficulty: socket.assigns.difficulty_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/moderator/words")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    word = Content.get_word!(id)

    case Content.delete_word(word) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word deleted successfully."))
         |> push_patch(to: ~p"/moderator/words")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete word. It may be in use."))}
    end
  end

  @impl true
  def handle_event("clear_feedback", _params, socket) do
    {:noreply, socket}
  end

  defp difficulty_badge_color(5), do: "badge-success"
  defp difficulty_badge_color(4), do: "badge-info"
  defp difficulty_badge_color(3), do: "badge-warning"
  defp difficulty_badge_color(2), do: "badge-error"
  defp difficulty_badge_color(1), do: "badge-secondary"
  defp difficulty_badge_color(_), do: "badge-ghost"
end
