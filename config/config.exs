import Config

config :plausible,
  ecto_repos: [Plausible.Repo, Plausible.ClickhouseRepo],
  session_length_minutes: 30

config :plausible, :ingestion,
  buffer_size: 10_000,
  flush_interval_ms: 5000

config :plausible, :user_agent_cache,
  limit: 1000,
  stats: false

config :plausible, Oban,
  repo: Plausible.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 2_592_000}],
  queues: [
    rotate_salts: 1
  ],
  crontab: [
    {"0 0 * * *", Plausible.Tracking.Workers.RotateSalts}
  ]

config :plausible, Plausible.Telemetry.DatadogStatsd,
  enabled: System.get_env("ENABLE_DD_STATS") || false

config :plausible, PlausibleWeb.Endpoint, pubsub_server: Plausible.PubSub

config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :opentelemetry_exporter,
  endpoints: [],
  otlp_protocol: :http_protobuf,
  log_level: :error

config :phoenix, :json_library, Jason

config :ua_inspector,
  database_path: Path.expand("../priv/ua_inspector", __DIR__)

config :ref_inspector,
  database_path: Path.expand("../priv/ref_inspector", __DIR__)

import_config "#{config_env()}.exs"
