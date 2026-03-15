defmodule MedoruWeb.UserAuth do
  @moduledoc """
  Authentication and authorization plugs for Medoru.
  """
  use MedoruWeb, :verified_routes
  use Gettext, backend: MedoruWeb.Gettext
  import Plug.Conn
  import Phoenix.Controller
  alias Medoru.Accounts
  alias Medoru.Notifications

  @doc """
  Plug that fetches the current user from the session.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user_with_profile(user_id)
    unread_count = if user, do: Notifications.count_unread_notifications(user.id), else: 0
    locale = conn.assigns[:locale] || "en"

    conn
    |> assign(:current_user, user)
    |> assign(:current_scope, %{current_user: user, unread_count: unread_count, locale: locale})
  end

  @doc """
  Plug that requires an authenticated user.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, gettext("You must log in to access this page."))
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Authenticates the user in LiveView sockets.
  """
  def on_mount(:default, params, session, socket) do
    socket = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)
    {:cont, socket}
  end

  def on_mount(:require_authenticated_user, params, session, socket) do
    socket = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)

    if socket.assigns.current_scope.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, params, session, socket) do
    socket = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)

    if socket.assigns.current_scope.current_user do
      socket =
        socket
        |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  defp set_locale(socket, params, session) do
    locale = params["locale"] || session["locale"] || "en"

    if locale in ["en", "bg", "ja"] do
      Gettext.put_locale(MedoruWeb.Gettext, locale)

      # Update scope with locale
      current_scope = socket.assigns.current_scope
      new_scope = Map.put(current_scope, :locale, locale)
      Phoenix.Component.assign(socket, :current_scope, new_scope)
    else
      socket
    end
  end

  defp mount_current_user(session, socket) do
    locale = session["locale"] || "en"

    case session do
      %{"user_id" => user_id} ->
        # Use get_user_with_profile to load display name and avatar
        # Returns nil if user no longer exists (e.g., database cleaned)
        user = Accounts.get_user_with_profile(user_id)
        unread_count = if user, do: Notifications.count_unread_notifications(user.id), else: 0

        Phoenix.Component.assign(socket,
          current_scope: %{current_user: user, unread_count: unread_count, locale: locale}
        )

      %{} ->
        Phoenix.Component.assign(socket,
          current_scope: %{current_user: nil, unread_count: 0, locale: locale}
        )
    end
  end

  # Plug callbacks for pipeline usage
  def init(action) when is_atom(action), do: action

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])
end
