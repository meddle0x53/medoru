defmodule MedoruWeb.Plugs.Moderator do
  @moduledoc """
  Plug and on_mount hook for moderator-only access.
  Moderators can manage words and kanji.
  Admins also have implicit access.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Medoru.Accounts.User

  @doc """
  Plug for requiring moderator or admin access.
  """
  def require_moderator(conn, _opts) do
    user = conn.assigns[:current_scope][:current_user]

    if user && User.staff?(user) do
      conn
    else
      conn
      |> put_flash(:error, "You must be a moderator to access this page.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount hook for moderator-only live sessions.
  """
  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if User.staff?(user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be a moderator to access this page.")
        |> Phoenix.LiveView.redirect(to: "/dashboard")

      {:halt, socket}
    end
  end
end
