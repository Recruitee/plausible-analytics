defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller

  plug PlausibleWeb.AuthorizeSiteAccess when action == :stats

  def stats(%{assigns: %{site: %{domain: "all"} = site}} = conn, _params) do
    conn
    |> put_resp_header("x-robots-tag", "noindex")
    |> render("stats.html",
      site: site,
      has_goals: false,
      title: "Careers Analytics",
      offer_email_report: false,
      demo: false
    )
  end

  def stats(%{assigns: %{site: site}} = conn, _params) do
    has_stats = Plausible.Sites.has_stats?(site)
    can_see_stats = !site.locked || conn.assigns[:current_user_role] == :super_admin

    cond do
      has_stats && can_see_stats ->
        demo = site.domain == PlausibleWeb.Endpoint.host()
        offer_email_report = get_session(conn, site.domain <> "_offer_email_report")

        conn
        |> put_resp_header("x-robots-tag", "noindex")
        |> render("stats.html",
          site: site,
          has_goals: false,
          title: "Plausible · " <> site.domain,
          offer_email_report: offer_email_report,
          demo: demo
        )

      !has_stats && can_see_stats ->
        conn
        |> render("waiting_first_pageview.html", site: site)

      site.locked ->
        owner = Plausible.Sites.owner_for(site)

        conn
        |> render("site_locked.html", owner: owner, site: site)
    end
  end
end
