defmodule MedoruWeb.QA.BypassController do
  @moduledoc """
  QA Authentication Bypass Controller

  This controller provides authentication bypass for E2E testing.
  ONLY available in QA environment (MIX_ENV=qa).

  Allows direct login as any test user without OAuth.
  """
  use MedoruWeb, :controller

  alias Medoru.Accounts

  @doc """
  Shows the QA login page with available test users.
  """
  def index(conn, _params) do
    # Only available in QA mode
    unless qa_mode?() do
      conn
      |> put_status(:not_found)
      |> text("QA bypass only available in QA environment")
      |> halt()
    end

    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  @doc """
  Logs in as a specific user by ID (for programmatic access).

  POST /qa/bypass/login
  Body: %{"user_id" => user_id} or %{"email" => email}
  """
  def login(conn, %{"user_id" => user_id}) do
    unless qa_mode?() do
      return_not_found(conn)
    end

    case Accounts.get_user(user_id) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: "/qa/bypass")

      user ->
        conn
        |> put_flash(:info, "Logged in as #{user.email}")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/")
    end
  end

  def login(conn, %{"email" => email}) do
    unless qa_mode?() do
      return_not_found(conn)
    end

    case Accounts.get_user_by_email(email) do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: "/qa/bypass")

      user ->
        conn
        |> put_flash(:info, "Logged in as #{user.email}")
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/")
    end
  end

  @doc """
  Quick login endpoint for Playwright tests.
  Returns JSON response for easier test integration.

  POST /qa/bypass/api/login
  Body: %{"email" => email}
  Response: %{"success" => true, "user" => user_data}
  """
  def api_login(conn, %{"email" => email}) do
    unless qa_mode?() do
      conn
      |> put_status(:not_found)
      |> json(%{error: "QA bypass only available in QA environment"})
    end

    case Accounts.get_user_by_email(email) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> json(%{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            type: user.type
          }
        })
    end
  end

  @doc """
  Logs out the current user.
  """
  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Logged out")
    |> redirect(to: "/qa/bypass")
  end

  @doc """
  Returns list of test users as JSON for Playwright fixtures.

  GET /qa/bypass/api/users
  """
  def list_users(conn, _params) do
    unless qa_mode?() do
      return_not_found(conn)
    end

    users =
      Accounts.list_users()
      |> Enum.map(fn user ->
        %{
          id: user.id,
          email: user.email,
          name: user.name,
          type: user.type,
          avatar_url: user.avatar_url
        }
      end)

    json(conn, %{users: users})
  end

  @doc """
  Health check endpoint for Playwright to verify QA server is ready.

  GET /qa/health
  """
  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      environment: "qa",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Deletes the current user's daily test for the day.
  This allows tests to reset and regenerate the daily test.

  DELETE /qa/api/daily-test
  """
  def delete_daily_test(conn, _params) do
    unless qa_mode?() do
      return_not_found(conn)
    end

    user_id = get_session(conn, :user_id)

    if is_nil(user_id) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
    else
      case Medoru.Learning.delete_user_daily_test(user_id) do
        {:ok, :deleted} ->
          json(conn, %{success: true, message: "Daily test deleted"})

        {:ok, :no_test_found} ->
          json(conn, %{success: true, message: "No daily test found to delete"})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to delete daily test", reason: inspect(reason)})
      end
    end
  end

  defp qa_mode? do
    Application.get_env(:medoru, :qa_mode, false)
  end

  defp return_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("Not found")
    |> halt()
  end
end
