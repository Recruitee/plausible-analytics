defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_header("x-robots-tag", "noindex")
    |> render("index.html", site: %{}, title: "Careers Analytics")
  end
end
