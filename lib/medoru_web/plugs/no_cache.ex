defmodule MedoruWeb.Plugs.NoCache do
  @moduledoc """
  Sets Cache-Control headers to prevent browser caching of HTML pages.
  This prevents stale CSRF tokens when pages are served from cache.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    put_resp_header(conn, "cache-control", "no-store, no-cache, must-revalidate, max-age=0")
  end
end
