defmodule MedoruWeb.LessonLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "*.html"

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    page = parse_page(params["page"])
    search = parse_search(params["search"])

    result =
      Content.list_lessons_paginated(
        page: page,
        per_page: @per_page,
        difficulty: difficulty,
        search: search
      )

    # Fetch lesson progress for all lessons if user is authenticated
    lesson_progress_map =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        user_id = socket.assigns.current_scope.current_user.id
        lesson_ids = Enum.map(result.lessons, & &1.id)

        Learning.list_lesson_progress(user_id)
        |> Enum.filter(&(&1.lesson_id in lesson_ids))
        |> Map.new(&{&1.lesson_id, &1})
      else
        %{}
      end

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:page, page)
     |> assign(:search, search)
     |> assign(:lessons, result.lessons)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:per_page, @per_page)
     |> assign(:lesson_progress_map, lesson_progress_map)
     |> assign(:page_title, page_title(difficulty, search))}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    params =
      [
        difficulty: socket.assigns.difficulty,
        search: query,
        page: 1
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    {:noreply, push_patch(socket, to: ~p"/lessons?#{params}")}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    params =
      [
        difficulty: socket.assigns.difficulty,
        page: 1
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    {:noreply, push_patch(socket, to: ~p"/lessons?#{params}")}
  end

  defp page_title(nil, nil), do: gettext("All Lessons")

  defp page_title(difficulty, nil),
    do: gettext("JLPT N%{difficulty} Lessons", difficulty: difficulty)

  defp page_title(_difficulty, search), do: gettext("Search: %{search}", search: search)

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

  # Helper for template: generate page link params
  def page_link_params(assigns, page) do
    assigns = Map.new(assigns)

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: page
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end
end
