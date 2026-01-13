defmodule PlausibleWeb.AuthPlug do
  import Plug.Conn
  import Ecto.Query

  alias Plausible.Repo

  def init(options) do
    options
  end

  def call(conn, _opts) do
    user = Plausible.Auth.User |> limit(1) |> Repo.one()

    assign(conn, :current_user, user)
  end
end
