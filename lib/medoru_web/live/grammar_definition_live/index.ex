defmodule MedoruWeb.GrammarDefinitionLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  embed_templates "index.html"

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    current_user =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        socket.assigns.current_scope.current_user
      else
        nil
      end

    learned_grammar_ids =
      if current_user do
        Learning.list_learned_grammar_definition_ids_for_user(current_user.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:page_title, gettext("Grammar"))
     |> assign(:learned_grammar_ids, learned_grammar_ids)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])
    jlpt_level = parse_jlpt_level(params["level"])
    search = parse_search(params["search"])

    result =
      Content.list_grammar_definitions(
        page: page,
        per_page: @per_page,
        jlpt_level: jlpt_level,
        search: search
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:total_pages, result.total_pages)
     |> assign(:total_count, result.total_count)
     |> assign(:grammar_definitions, result.grammar_definitions)
     |> assign(:jlpt_level, jlpt_level)
     |> assign(:search, search)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(to: ~p"/grammars?#{%{level: socket.assigns.jlpt_level, search: search_param}}")}
  end

  @impl true
  def handle_event("filter_level", %{"level" => level}, socket) do
    level_param =
      case Integer.parse(level) do
        {n, _} when n in 1..5 -> n
        _ -> nil
      end

    {:noreply,
     socket
     |> push_patch(to: ~p"/grammars?#{%{level: level_param, search: socket.assigns.search}}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/grammars")}
  end

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page), do: max(1, String.to_integer(page))
  defp parse_page(page) when is_integer(page), do: max(1, page)

  defp parse_jlpt_level(nil), do: nil

  defp parse_jlpt_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..5 -> n
      _ -> nil
    end
  end

  defp parse_search(nil), do: nil
  defp parse_search(""), do: nil
  defp parse_search(search) when is_binary(search), do: String.trim(search)

  defp level_badge_color(5), do: "badge-success"
  defp level_badge_color(4), do: "badge-info"
  defp level_badge_color(3), do: "badge-warning"
  defp level_badge_color(2), do: "badge-error"
  defp level_badge_color(1), do: "badge-secondary"
  defp level_badge_color(_), do: "badge-ghost"
end
