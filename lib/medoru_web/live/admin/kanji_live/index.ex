defmodule MedoruWeb.Admin.KanjiLive.Index do
  @moduledoc """
  Admin interface for listing and managing kanji.
  """
  use MedoruWeb, :live_view

  import Ecto.Query, warn: false

  alias Medoru.Content
  alias Medoru.Content.Kanji
  alias Medoru.Repo

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

    %{kanji: kanji, total_count: total_count, total_pages: total_pages} =
      list_kanji_for_admin(
        page: page,
        per_page: @per_page,
        level: level_filter,
        search: search
      )

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Kanji"))
     |> assign(:kanji, kanji)
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
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
     |> push_patch(to: ~p"/admin/kanji?#{%{level: level_param, search: socket.assigns.search}}")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to: ~p"/admin/kanji?#{%{level: socket.assigns.level_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/kanji")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    kanji = Content.get_kanji!(id)

    case Content.delete_kanji(kanji) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Kanji deleted successfully."))
         |> push_patch(to: ~p"/admin/kanji")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete kanji. It may be in use."))}
    end
  end

  defp list_kanji_for_admin(opts) do
    page_num = Keyword.get(opts, :page, 1)
    per_page_count = Keyword.get(opts, :per_page, @per_page)
    level = Keyword.get(opts, :level)
    search = Keyword.get(opts, :search)

    query = Kanji

    # Apply level filter
    query = if level, do: where(query, jlpt_level: ^level), else: query

    # Apply search filter
    query =
      if search && search != "" do
        search_term = "%#{search}%"

        query
        |> where(
          [k],
          ilike(k.character, ^search_term) or
            fragment("? && ?", k.meanings, ^[search])
        )
      else
        query
      end

    # Get total count
    total_count = query |> select([k], count(k.id)) |> Repo.one()
    total_pages = max(1, ceil(total_count / per_page_count))

    # Calculate offset
    offset = (page_num - 1) * per_page_count

    # Apply ordering and pagination
    kanji =
      query
      |> order_by([k], asc: k.jlpt_level, desc: k.frequency)
      |> limit(^per_page_count)
      |> offset(^offset)
      |> preload(:kanji_readings)
      |> Repo.all()

    %{kanji: kanji, total_count: total_count, total_pages: total_pages}
  end

  defp level_badge_color(5), do: "badge-success"
  defp level_badge_color(4), do: "badge-info"
  defp level_badge_color(3), do: "badge-warning"
  defp level_badge_color(2), do: "badge-error"
  defp level_badge_color(1), do: "badge-secondary"
  defp level_badge_color(_), do: "badge-ghost"
end
