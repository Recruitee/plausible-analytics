import Config

config :plausible, PlausibleWeb.Endpoint,
  secret_key_base: "TDUfsgsmQMuWs+xPOULLw5agLZUZyJfcX/KpQPYE6xnILFiY7NgHqgIlxYKGiW0f",
  url: [
    scheme: "http",
    host: "localhost",
    port: 8000
  ],
  http: [
    port: 8000,
    ip: {127, 0, 0, 1}
  ],
  render_errors: [
    view: PlausibleWeb.ErrorView,
    accepts: ~w(html json)
  ],
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{lib/plausible_web/views/.*(ex)$},
      ~r{lib/plausible_web/templates/.*(eex)$},
      ~r{lib/plausible_web/controllers/.*(ex)$},
      ~r{lib/plausible_web/plugs/.*(ex)$}
    ]
  ]

config :plausible, Plausible.Repo,
  username: "postgres",
  password: "postgres",
  database: "plausible_dev",
  hostname: "127.0.0.1",
  port: 5430,
  pool_size: 10,
  queue_target: 2000,
  queue_interval: 1000,
  timeout: 60_000

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  queue_target: 500,
  queue_interval: 2000,
  database: "plausible_events_dev_db",
  hostname: "127.0.0.1",
  port: 18123

config :plausible,
  system_environment: "dev"

config :logger,
  level: :debug,
  console: [
    format: "[$level] $message\n"
  ]

# Uncomment to enable console telemetry reporter for debugging
# config :plausible, telemetry_console_reporter: true

config :opentelemetry, traces_exporter: :none

config :phoenix, :plug_init_mode, :runtime
