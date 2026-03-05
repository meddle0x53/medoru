defmodule MedoruWeb.UserAuth do
  @moduledoc """
  Authentication and authorization plugs for Medoru.
  """
  use MedoruWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias Medoru.Accounts

  @doc """
  Plug that fetches the current user from the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)

    conn
    |> assign(:current_user, user)
    |> assign(:current_scope, %{current_user: user})
  end

  @doc """
  Plug that requires an authenticated user.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Authenticates the user in LiveView sockets.
  """
  def on_mount(:default, _params, session, socket) do
    socket = mount_current_user(session, socket)
    {:cont, socket}
  end

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_scope.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_scope.current_user do
      socket =
        socket
        |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user!(user_id)
        Phoenix.Component.assign(socket, current_scope: %{current_user: user})

      %{} ->
        Phoenix.Component.assign(socket, current_scope: %{current_user: nil})
    end
  end

  # Plug callbacks for pipeline usage
  def init(action) when is_atom(action), do: action

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])
end
