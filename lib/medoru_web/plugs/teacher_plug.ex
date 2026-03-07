defmodule MedoruWeb.Plugs.Teacher do
  @moduledoc """
  Plug and on_mount hook for teacher+admin access.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Medoru.Accounts.User

  @doc """
  Plug for requiring teacher or admin access.
  """
  def require_teacher(conn, _opts) do
    user = conn.assigns[:current_scope][:current_user]

    if user && User.teacher?(user) do
      conn
    else
      conn
      |> put_flash(:error, "You must be a teacher to access this page.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  @doc """
  LiveView on_mount hook for teacher+admin live sessions.
  """
  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if User.teacher?(user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be a teacher to access this page.")
        |> Phoenix.LiveView.redirect(to: "/dashboard")

      {:halt, socket}
    end
  end

  @doc """
  Returns true if the current user is a teacher or admin.
  Useful for conditional rendering in templates.
  """
  def teacher?(socket) do
    socket.assigns.current_scope.current_user
    |> User.teacher?()
  end
end
