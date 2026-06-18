defmodule MedoruWeb.Admin.UserController do
  @moduledoc """
  Admin-only controller for user management actions that require
  a full HTTP request/response cycle (impersonation, etc.).
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts
  alias Medoru.Accounts.User
  alias MedoruWeb.UserAuth

  @doc """
  Starts impersonating another user.

  Stores the admin's real user ID under `:impersonator_user_id` and sets
  `:user_id` to the target user. This works across regular controllers and
  LiveViews because all auth code reads `:user_id` from the session.
  """
  def impersonate(conn, %{"id" => user_id}) do
    current_user = conn.assigns.current_scope.current_user

    if is_nil(current_user) or not User.admin?(current_user) do
      conn
      |> put_flash(:error, gettext("You must be an admin to access this page."))
      |> redirect(to: ~p"/dashboard")
      |> halt()
    else
      do_impersonate(conn, current_user, user_id)
    end
  end

  defp do_impersonate(conn, current_user, user_id) do
    target_user = Accounts.get_user(user_id)

    cond do
      is_nil(target_user) ->
        conn
        |> put_flash(:error, gettext("User not found."))
        |> redirect(to: ~p"/admin/users")

      User.admin?(target_user) ->
        conn
        |> put_flash(:error, gettext("You cannot impersonate another admin."))
        |> redirect(to: ~p"/admin/users")

      true ->
        conn
        |> put_session(:impersonator_user_id, current_user.id)
        |> put_session(:user_id, target_user.id)
        |> put_flash(
          :info,
          gettext("You are now impersonating %{name}.", name: target_user.name || target_user.email)
        )
        |> redirect(to: ~p"/dashboard")
    end
  end

  @doc """
  Stops impersonation and restores the original admin session.
  """
  def stop_impersonation(conn, _params) do
    impersonator_user_id = get_session(conn, :impersonator_user_id)
    impersonator_user = impersonator_user_id && Accounts.get_user(impersonator_user_id)

    if impersonator_user && User.admin?(impersonator_user) do
      conn
      |> UserAuth.stop_impersonation()
      |> put_flash(:info, gettext("Impersonation ended. You are logged back in as yourself."))
      |> redirect(to: ~p"/admin/users")
    else
      conn
      |> put_flash(:error, gettext("You are not impersonating anyone."))
      |> redirect(to: ~p"/dashboard")
    end
  end
end
