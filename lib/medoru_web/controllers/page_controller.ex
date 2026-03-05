defmodule MedoruWeb.PageController do
  use MedoruWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
