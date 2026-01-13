defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller

  def index(conn, _params) do
    conn
    |> redirect(to: "/all")
    |> halt()
  end
end
