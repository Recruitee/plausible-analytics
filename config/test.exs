import Config

config :plausible, PlausibleWeb.Endpoint,
  server: false,
  url: [scheme: "http", host: "localhost", port: 8000],
  http: [port: 8000, ip: {127, 0, 0, 1}],
  secret_key_base: "/njrhntbycvastyvtk1zycwfm981vpo/0xrvwjjvemdakc/vsvbrevlwsc6u8rcg"

config :plausible, Plausible.Repo,
  username: "postgres",
  password: "postgres",
  database: "plausible_test",
  hostname: "localhost",
  port: 5430,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 2000,
  queue_interval: 1000,
  timeout: 60_000

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  queue_target: 500,
  queue_interval: 2000,
  database: "plausible_events_test_db",
  hostname: "localhost",
  port: 18123

config :plausible, Oban,
  repo: Plausible.Repo,
  testing: :inline,
  crontab: false,
  plugins: false

config :plausible,
  system_environment: "test"

config :plausible, :ingestion,
  buffer_size: 100,
  flush_interval_ms: 2000

config :plausible, :geolocation, Plausible.Geolocation.Mock

config :logger, level: :warning
