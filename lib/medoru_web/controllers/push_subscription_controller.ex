defmodule MedoruWeb.PushSubscriptionController do
  use MedoruWeb, :controller

  alias Medoru.Notifications

  def create(conn, %{"subscription" => subscription}) do
    user = conn.assigns.current_scope.current_user

    case Notifications.create_or_update_push_subscription(user.id, subscription) do
      {:ok, _sub} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "subscribed"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"endpoint" => endpoint}) do
    user = conn.assigns.current_scope.current_user
    Notifications.delete_push_subscription(user.id, endpoint)

    conn
    |> put_status(:ok)
    |> json(%{status: "unsubscribed"})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
