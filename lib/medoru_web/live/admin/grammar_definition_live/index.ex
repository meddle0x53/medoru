defmodule MedoruWeb.Admin.GrammarDefinitionLive.Index do
  @moduledoc """
  Admin interface for listing and managing grammar definitions.
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
    page = String.to_integer(params["page"] || "1")
    level_filter = params["level"]
    search = params["search"]

    result =
      Content.list_grammar_definitions(
        page: page,
        per_page: @per_page,
        jlpt_level: parse_level(level_filter),
        search: search
      )

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Grammar"))
     |> assign(:grammar_definitions, result.grammar_definitions)
     |> assign(:page, page)
     |> assign(:total_pages, result.total_pages)
     |> assign(:total_count, result.total_count)
     |> assign(:level_filter, level_filter)
     |> assign(:search, search)}
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
     |> push_patch(
       to: ~p"/admin/grammars?#{%{level: level_param, search: socket.assigns.search}}"
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to: ~p"/admin/grammars?#{%{level: socket.assigns.level_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/grammars")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    grammar_definition = Content.get_grammar_definition!(id)

    case Content.delete_grammar_definition(grammar_definition) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar point deleted successfully."))
         |> push_patch(to: ~p"/admin/grammars")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete grammar point."))}
    end
  end

  defp parse_level(nil), do: nil

  defp parse_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..5 -> n
      _ -> nil
    end
  end

  defp level_badge_color(5), do: "badge-success"
  defp level_badge_color(4), do: "badge-info"
  defp level_badge_color(3), do: "badge-warning"
  defp level_badge_color(2), do: "badge-error"
  defp level_badge_color(1), do: "badge-secondary"
  defp level_badge_color(_), do: "badge-ghost"
end
