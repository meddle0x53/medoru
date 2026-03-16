defmodule MedoruWeb.Admin.LessonLive.Index do
  @moduledoc """
  Admin interface for listing and managing lessons.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "index/*"

  @per_page 20

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
    page = String.to_integer(params["page"] || "1")
    difficulty_filter = params["difficulty"]
    search = params["search"]

    result =
      Content.list_lessons_paginated(
        page: page,
        per_page: @per_page,
        search: search,
        difficulty: if(difficulty_filter, do: String.to_integer(difficulty_filter), else: nil)
      )

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Lessons"))
     |> assign(:lessons, result.lessons)
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
       to: ~p"/admin/lessons?#{%{difficulty: diff_param, search: socket.assigns.search}}"
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/admin/lessons?#{%{difficulty: socket.assigns.difficulty_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/lessons")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    lesson = Content.get_lesson!(id)

    case Content.delete_lesson(lesson) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lesson deleted successfully."))
         |> push_patch(to: ~p"/admin/lessons")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete lesson. It may be in use."))}
    end
  end

  defp difficulty_badge_color(5), do: "badge-success"
  defp difficulty_badge_color(4), do: "badge-info"
  defp difficulty_badge_color(3), do: "badge-warning"
  defp difficulty_badge_color(2), do: "badge-error"
  defp difficulty_badge_color(1), do: "badge-secondary"
  defp difficulty_badge_color(_), do: "badge-ghost"

  defp lesson_type_icon(:reading), do: "hero-book-open"
  defp lesson_type_icon(:writing), do: "hero-pencil"
  defp lesson_type_icon(:listening), do: "hero-speaker-wave"
  defp lesson_type_icon(:speaking), do: "hero-chat-bubble-left"
  defp lesson_type_icon(:grammar), do: "hero-academic-cap"
  defp lesson_type_icon(_), do: "hero-book-open"
end
