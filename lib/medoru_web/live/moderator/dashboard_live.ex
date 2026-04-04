defmodule MedoruWeb.Moderator.DashboardLive do
  @moduledoc """
  Moderator dashboard with links to content management pages.
  """
  use MedoruWeb, :live_view

  embed_templates "dashboard_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {dashboard(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Moderator Dashboard"))}
  end
end
