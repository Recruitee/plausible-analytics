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

config :plausible, Plausible.Repo,
  timeout: 300_000,
  connect_timeout: 300_000,
  handshake_timeout: 300_000

config :plausible, :user_agent_cache,
  limit: 1000,
  stats: false

config :plausible, :ingestion,
  buffer_size: 10_000,
  flush_interval_ms: 5000

import_config "#{config_env()}.exs"
