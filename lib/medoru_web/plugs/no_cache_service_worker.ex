defmodule MedoruWeb.Plugs.NoCacheServiceWorker do
  @moduledoc """
  Prevents browser caching of service-worker.js.
  Browsers should always fetch the latest service worker script.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/service-worker.js"} = conn, _opts) do
    put_resp_header(conn, "cache-control", "no-store, no-cache, must-revalidate, max-age=0")
  end

  def call(conn, _opts), do: conn
end
