defmodule MedoruWeb.Api.V1.HealthController do
  @moduledoc """
  Health check endpoints for the public API.
  """
  use MedoruWeb, :controller

  alias Medoru.Repo

  @doc false
  def health(conn, _params) do
    json(conn, %{status: "ok"})
  end

  @doc false
  def db_health(conn, _params) do
    case Repo.query("SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ok"})

      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error"})
    end
  end
end
