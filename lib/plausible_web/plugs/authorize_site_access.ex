defmodule PlausibleWeb.AuthorizeSiteAccess do
  import Plug.Conn
  import Ecto.Query

  alias Plausible.Repo

  def init(opts), do: opts

  def call(conn, _opts) do
    site = Plausible.Site |> limit(1) |> Repo.one()

    merge_assigns(conn, site: site, current_user_role: :owner)
  end
end
