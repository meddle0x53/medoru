defmodule MedoruWeb.Api.V1.OpenApiController do
  @moduledoc """
  Serves the OpenAPI JSON spec for the public API.
  """
  use MedoruWeb, :controller

  @doc false
  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(MedoruWeb.ApiSpec.spec()))
  end
end
