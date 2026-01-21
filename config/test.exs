import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plausible, PlausibleWeb.Endpoint, server: false

config :bcrypt_elixir, :log_rounds, 4

config :plausible, Plausible.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  pool_size: 5

config :plausible,
  session_timeout: 0,
  env: :test

config :plausible, :ingestion,
  buffer_size: 100,
  flush_interval_ms: 2000

config :plausible, :geolocation, Plausible.Geolocation.Mock
