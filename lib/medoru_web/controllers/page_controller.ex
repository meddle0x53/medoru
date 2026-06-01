defmodule MedoruWeb.PageController do
  use MedoruWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def unavailable(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> render(:unavailable)
  end
end
