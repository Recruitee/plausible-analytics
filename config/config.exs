import Config

config :plausible,
  ecto_repos: [Plausible.Repo, Plausible.ClickhouseRepo]

config :plausible, PlausibleWeb.Endpoint, pubsub_server: Plausible.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :plausible,
  # 30 minutes
  session_timeout: 1000 * 60 * 30,
  session_length_minutes: 30

config :plausible, Plausible.ClickhouseRepo, loggers: [Ecto.LogEntry]

# Keep 30 days history

config :plausible, Oban,
  repo: Plausible.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 2_592_000}],
  queues: [
    rotate_salts: 1
  ],
  crontab: [
    {"0 0 * * *", Plausible.Tracking.Workers.RotateSalts}
  ]

config :plausible, :user_agent_cache,
  limit: 1000,
  stats: false

config :plausible, :ingestion,
  buffer_size: 10_000,
  flush_interval_ms: 5000

config :logger, backends: [:console]

config :logger, Sentry.LoggerBackend,
  capture_log_messages: true,
  level: :error,
  excluded_domains: []

import_config "#{config_env()}.exs"
