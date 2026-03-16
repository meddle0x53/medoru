defmodule MedoruWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard with system statistics overview.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Content
  alias Medoru.Classrooms

  embed_templates "dashboard_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {dashboard(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user_stats = Accounts.get_admin_stats()
    content_stats = Content.get_admin_stats()
    classroom_stats = Classrooms.get_admin_stats()

    {:ok,
     socket
     |> assign(:page_title, gettext("Admin Dashboard"))
     |> assign(:user_stats, user_stats)
     |> assign(:content_stats, content_stats)
     |> assign(:classroom_stats, classroom_stats)}
  end
end
