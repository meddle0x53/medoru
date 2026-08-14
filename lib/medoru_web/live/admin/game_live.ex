defmodule MedoruWeb.Admin.GameLive do
  @moduledoc """
  Admin-only game page for The Hollow Ouroboros MVP.
  """
  use MedoruWeb, :live_view

  embed_templates "game_live/*"

  @impl true
  def render(assigns) do
    ~H"""
    {game(assigns)}
    """
  end

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.current_user

    game_data = MedoruWeb.GameLive.build_game_data(user, session)

    socket =
      socket
      |> assign(:page_title, "The Hollow Ouroboros - Admin")
      |> assign(:game_data, Jason.encode!(game_data))

    {:ok, socket}
  end
end
