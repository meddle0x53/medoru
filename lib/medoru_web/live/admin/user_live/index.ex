defmodule MedoruWeb.Admin.UserLive.Index do
  @moduledoc """
  Admin interface for listing and managing users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Accounts.User

  embed_templates "index/*"

  @impl true
  def render(assigns) do
    ~H"""
    {index(assigns)}
    """
  end

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    type_filter = params["type"]
    search = params["search"]

    {users, total_count} =
      Accounts.list_users_for_admin(
        page: page,
        per_page: @per_page,
        type: type_filter,
        search: search
      )

    total_pages = safe_ceil(total_count)

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Users"))
     |> assign(:users, users)
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:type_filter, type_filter)
     |> assign(:search, search)
     |> assign(:user_types, User.types())}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    type_param = if type in ["student", "teacher", "admin"], do: type, else: nil

    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/users?#{%{type: type_param, search: socket.assigns.search}}")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    search_param = if query == "", do: nil, else: query

    {:noreply,
     socket
     |> push_patch(
       to: ~p"/admin/users?#{%{type: socket.assigns.type_filter, search: search_param}}"
     )}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/users")}
  end

  def type_badge_color("admin"), do: "badge-error"
  def type_badge_color("teacher"), do: "badge-warning"
  def type_badge_color("student"), do: "badge-info"
  def type_badge_color(_), do: "badge-ghost"

  defp safe_ceil(number) do
    trunc(Float.ceil(number / @per_page))
  end
end
