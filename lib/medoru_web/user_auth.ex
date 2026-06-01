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

    if user_id && is_nil(user) do
      # User ID in session but no active user found - check if deleted
      if Accounts.get_user_with_profile_including_deleted(user_id) do
        conn
        |> configure_session(drop: true)
        |> put_flash(:error, gettext("Your account has been suspended."))
        |> redirect(to: ~p"/not-available")
        |> halt()
      else
        # User ID no longer exists in DB (e.g., cleaned), clear session
        conn
        |> delete_session(:user_id)
        |> assign(:current_user, nil)
        |> assign(:current_scope, %{
          current_user: nil,
          unread_count: 0,
          locale: conn.assigns[:locale] || "en",
          theme: "system"
        })
      end
    else
      unread_count = if user, do: Notifications.count_unread_notifications(user.id), else: 0
      locale = conn.assigns[:locale] || "en"
      theme = if user && user.profile, do: user.profile.theme, else: "system"

      conn
      |> assign(:current_user, user)
      |> assign(:current_scope, %{
        current_user: user,
        unread_count: unread_count,
        locale: locale,
        theme: theme
      })
    end
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
    {action, socket} = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)
    {action, socket}
  end

  def on_mount(:require_authenticated_user, params, session, socket) do
    {action, socket} = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)

    cond do
      action == :halt ->
        {:halt, socket}

      socket.assigns.current_scope.current_user ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, gettext("You must log in to access this page."))
          |> Phoenix.LiveView.redirect(to: ~p"/")

        {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, params, session, socket) do
    {action, socket} = mount_current_user(session, socket)
    socket = set_locale(socket, params, session)

    cond do
      action == :halt ->
        {:halt, socket}

      socket.assigns.current_scope.current_user ->
        socket =
          socket
          |> Phoenix.LiveView.redirect(to: ~p"/dashboard")

        {:halt, socket}

      true ->
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
        case maybe_get_active_user(user_id) do
          {:deleted, _} ->
            {:halt,
             socket
             |> Phoenix.LiveView.put_flash(:error, gettext("Your account has been suspended."))
             |> Phoenix.LiveView.redirect(to: ~p"/not-available")}

          {:ok, user} ->
            unread_count = if user, do: Notifications.count_unread_notifications(user.id), else: 0
            theme = if user && user.profile, do: user.profile.theme, else: "system"

            {:cont,
             Phoenix.Component.assign(socket,
               current_scope: %{
                 current_user: user,
                 unread_count: unread_count,
                 locale: locale,
                 theme: theme
               }
             )}
        end

      %{} ->
        {:cont,
         Phoenix.Component.assign(socket,
           current_scope: %{current_user: nil, unread_count: 0, locale: locale, theme: "system"}
         )}
    end
  end

  defp maybe_get_active_user(user_id) do
    case Accounts.get_user_with_profile(user_id) do
      nil ->
        if Accounts.get_user_with_profile_including_deleted(user_id) do
          {:deleted, nil}
        else
          {:ok, nil}
        end

      user ->
        {:ok, user}
    end
  end

  # Plug callbacks for pipeline usage
  def init(action) when is_atom(action), do: action

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated_user), do: require_authenticated_user(conn, [])
end
