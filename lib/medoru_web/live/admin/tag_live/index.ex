defmodule MedoruWeb.Admin.TagLive.Index do
  @moduledoc """
  Admin interface for listing and managing tags.
  """
  use MedoruWeb, :live_view

  alias Medoru.Social

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

    category_filter = params["category"]
    search = params["search"]

    result =
      Social.list_tags_paginated(
        page: page,
        per_page: @per_page,
        search: search,
        category: category_filter
      )

    categories = Social.list_tag_categories()

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Tags"))
     |> assign(:tags, result.tags)
     |> assign(:page, result.current_page)
     |> assign(:total_pages, result.total_pages)
     |> assign(:total_count, result.total_count)
     |> assign(:category_filter, category_filter)
     |> assign(:categories, categories)
     |> assign(:search, search)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    cat_param = if category == "", do: nil, else: category

    {:noreply,
     socket
     |> push_patch(
       to: ~p"/admin/tags?#{%{category: cat_param, search: socket.assigns.search}}"
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to:
         ~p"/admin/tags?#{%{category: socket.assigns.category_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/tags")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tag = Social.get_tag!(id)

    case Social.delete_tag(tag) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Tag deleted successfully."))
         |> push_patch(to: ~p"/admin/tags")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete tag. It may be in use."))}
    end
  end

  @doc """
  Maps tag color names to Tailwind bg/text classes.
  Uses explicit pattern matches so Tailwind JIT picks up the classes.
  """
  def tag_color_classes("red"), do: "bg-red-500 text-white"
  def tag_color_classes("orange"), do: "bg-orange-500 text-white"
  def tag_color_classes("amber"), do: "bg-amber-500 text-white"
  def tag_color_classes("yellow"), do: "bg-yellow-400 text-black"
  def tag_color_classes("lime"), do: "bg-lime-500 text-white"
  def tag_color_classes("green"), do: "bg-green-500 text-white"
  def tag_color_classes("emerald"), do: "bg-emerald-500 text-white"
  def tag_color_classes("teal"), do: "bg-teal-500 text-white"
  def tag_color_classes("cyan"), do: "bg-cyan-500 text-white"
  def tag_color_classes("sky"), do: "bg-sky-500 text-white"
  def tag_color_classes("blue"), do: "bg-blue-500 text-white"
  def tag_color_classes("indigo"), do: "bg-indigo-500 text-white"
  def tag_color_classes("violet"), do: "bg-violet-500 text-white"
  def tag_color_classes("purple"), do: "bg-purple-500 text-white"
  def tag_color_classes("fuchsia"), do: "bg-fuchsia-500 text-white"
  def tag_color_classes("pink"), do: "bg-pink-500 text-white"
  def tag_color_classes("rose"), do: "bg-rose-500 text-white"
  def tag_color_classes("slate"), do: "bg-slate-500 text-white"
  def tag_color_classes("stone"), do: "bg-stone-500 text-white"
  def tag_color_classes("primary"), do: "bg-primary text-primary-content"
  def tag_color_classes("secondary"), do: "bg-secondary text-secondary-content"
  def tag_color_classes("accent"), do: "bg-accent text-accent-content"
  def tag_color_classes("info"), do: "bg-info text-info-content"
  def tag_color_classes("success"), do: "bg-success text-success-content"
  def tag_color_classes("warning"), do: "bg-warning text-warning-content"
  def tag_color_classes("error"), do: "bg-error text-error-content"
  def tag_color_classes(_), do: "bg-base-300 text-base-content"
end
