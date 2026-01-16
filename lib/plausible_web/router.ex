defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :internal_stats_api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/api/stats", PlausibleWeb.Api do
    pipe_through :internal_stats_api

    get "/:domain/current-visitors", StatsController, :current_visitors
    get "/:domain/main-graph", StatsController, :main_graph
    get "/:domain/sources", StatsController, :sources
    get "/:domain/utm_mediums", StatsController, :utm_mediums
    get "/:domain/utm_sources", StatsController, :utm_sources
    get "/:domain/utm_campaigns", StatsController, :utm_campaigns
    get "/:domain/utm_contents", StatsController, :utm_contents
    get "/:domain/utm_terms", StatsController, :utm_terms
    get "/:domain/referrers/:referrer", StatsController, :referrer_drilldown
    get "/:domain/pages", StatsController, :pages
    get "/:domain/entry-pages", StatsController, :entry_pages
    get "/:domain/exit-pages", StatsController, :exit_pages
    get "/:domain/countries", StatsController, :countries
    get "/:domain/regions", StatsController, :regions
    get "/:domain/cities", StatsController, :cities
    get "/:domain/browsers", StatsController, :browsers
    get "/:domain/browser-versions", StatsController, :browser_versions
    get "/:domain/operating-systems", StatsController, :operating_systems
    get "/:domain/operating-system-versions", StatsController, :operating_system_versions
    get "/:domain/screen-sizes", StatsController, :screen_sizes
    get "/:domain/suggestions/:filter_name", StatsController, :filter_suggestions
  end

  scope "/api", PlausibleWeb do
    pipe_through :api

    post "/event", Api.ExternalController, :event
  end

  scope "/", PlausibleWeb do
    pipe_through :browser

    get "/", StatsController, :index
  end
end
