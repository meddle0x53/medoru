defmodule MedoruWeb.AuthController do
  @moduledoc """
  Handles OAuth authentication callbacks.
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts
  alias Medoru.Accounts.User

  plug Ueberauth

  @doc """
  Handles the OAuth callback from Google.
  """
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      provider: "google",
      provider_uid: auth.uid,
      name: auth.info.name,
      avatar_url: auth.info.image
    }

    case Accounts.get_user_by_provider_uid("google", auth.uid) do
      nil ->
        # New user - register them
        case Accounts.register_user_with_oauth(user_params) do
          {:ok, %User{} = user} ->
            conn
            |> put_flash(:info, "Welcome to Medoru, #{user.name || user.email}!")
            |> put_session(:user_id, user.id)
            |> configure_session(renew: true)
            |> redirect(to: ~p"/dashboard")

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_flash(:error, "Could not create account: #{inspect_errors(changeset)}")
            |> redirect(to: ~p"/")
        end

      %User{} = user ->
        # Existing user - log them in
        conn
        |> put_flash(:info, "Welcome back, #{user.name || user.email}!")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/dashboard")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Authentication failed: #{failure.message}")
    |> redirect(to: ~p"/")
  end

  @doc """
  Logs out the current user.
  """
  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/")
  end

  defp inspect_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%\{(\w+)\}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end
end
