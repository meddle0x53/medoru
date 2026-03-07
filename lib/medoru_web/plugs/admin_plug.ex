defmodule MedoruWeb.Plugs.Admin do
  @moduledoc """
  Plug and on_mount hook for admin-only access.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Medoru.Accounts.User

  @doc """
  Plug for requiring admin access.
  """
  def require_admin(conn, _opts) do
    user = conn.assigns[:current_scope][:current_user]

    if user && User.admin?(user) do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount hook for admin-only live sessions.
  """
  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if User.admin?(user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be an admin to access this page.")
        |> Phoenix.LiveView.redirect(to: "/dashboard")

      {:halt, socket}
    end
  end

  @doc """
  Returns true if the current user is an admin.
  Useful for conditional rendering in templates.
  """
  def admin?(socket) do
    socket.assigns.current_scope.current_user
    |> User.admin?()
  end
end
