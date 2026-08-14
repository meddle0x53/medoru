defmodule MedoruWeb.Plugs.CORS do
  @moduledoc """
  Minimal CORS plug for the public API.

  Allows read-only cross-origin requests from any origin. For a production
  deployment you may want to restrict the allowed origins.
  """

  @behaviour Plug

  @allowed_methods "GET, OPTIONS"
  @allowed_headers "content-type, accept"
  @allowed_origin "*"
  @max_age "86400"

  @impl Plug
  def init(options), do: options

  @impl Plug
  def call(%Plug.Conn{method: "OPTIONS", request_path: "/api/v1" <> _} = conn, _opts) do
    conn
    |> put_cors_headers()
    |> Plug.Conn.send_resp(204, "")
    |> Plug.Conn.halt()
  end

  def call(%Plug.Conn{request_path: "/api/v1" <> _} = conn, _opts) do
    put_cors_headers(conn)
  end

  def call(conn, _opts), do: conn

  defp put_cors_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", @allowed_origin)
    |> Plug.Conn.put_resp_header("access-control-allow-methods", @allowed_methods)
    |> Plug.Conn.put_resp_header("access-control-allow-headers", @allowed_headers)
    |> Plug.Conn.put_resp_header("access-control-max-age", @max_age)
  end
end
