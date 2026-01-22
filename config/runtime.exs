import Config
import Plausible.ConfigHelpers

if config_env() in [:dev, :test] do
  Envy.load(["config/.env.#{config_env()}"])
end

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

# Listen IP supports IPv4 and IPv6 addresses.
listen_ip =
  (
    str = get_var_from_path_or_env(config_dir, "LISTEN_IP") || "127.0.0.1"

    case :inet.parse_address(String.to_charlist(str)) do
      {:ok, ip_addr} ->
        ip_addr

      {:error, reason} ->
        raise "Invalid LISTEN_IP '#{str}' error: #{inspect(reason)}"
    end
  )

# System.get_env does not accept a non string default
port = get_var_from_path_or_env(config_dir, "PORT") || 8000
base_url = get_var_from_path_or_env(config_dir, "BASE_URL")
base_url = URI.parse(base_url)

secret_key_base = get_var_from_path_or_env(config_dir, "SECRET_KEY_BASE", nil)

db_url =
  get_var_from_path_or_env(
    config_dir,
    "DATABASE_URL",
    "postgres://postgres:postgres@plausible_db:5432/plausible_db"
  )

db_socket_dir = get_var_from_path_or_env(config_dir, "DATABASE_SOCKET_DIR")

env = get_var_from_path_or_env(config_dir, "ENVIRONMENT", "prod")
app_version = get_var_from_path_or_env(config_dir, "APP_VERSION", "0.0.1")

ch_db_url =
  get_var_from_path_or_env(
    config_dir,
    "CLICKHOUSE_DATABASE_URL",
    "http://plausible_events_db:8123/plausible_events_db"
  )

### Mandatory params End

sentry_dsn = get_var_from_path_or_env(config_dir, "SENTRY_DSN")

geolite2_country_db =
  get_var_from_path_or_env(
    config_dir,
    "GEOLITE2_COUNTRY_DB",
    Application.app_dir(:plausible) <> "/priv/geodb/dbip-country.mmdb"
  )

ip_geolocation_db = get_var_from_path_or_env(config_dir, "IP_GEOLOCATION_DB", geolite2_country_db)
geonames_source_file = get_var_from_path_or_env(config_dir, "GEONAMES_SOURCE_FILE")

{user_agent_cache_limit, ""} =
  config_dir
  |> get_var_from_path_or_env("USER_AGENT_CACHE_LIMIT", "1000")
  |> Integer.parse()

user_agent_cache_stats =
  config_dir
  |> get_var_from_path_or_env("USER_AGENT_CACHE_STATS", "false")
  |> String.to_existing_atom()

config :plausible,
  environment: env,
  system_environment: env

config :plausible, PlausibleWeb.Endpoint,
  url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
  http: [port: port, ip: listen_ip, transport_options: [max_connections: :infinity]],
  secret_key_base: secret_key_base

maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

if is_nil(db_socket_dir) do
  config :plausible, Plausible.Repo,
    url: db_url,
    socket_options: maybe_ipv6
else
  config :plausible, Plausible.Repo,
    socket_dir: db_socket_dir,
    database: get_var_from_path_or_env(config_dir, "DATABASE_NAME", "plausible")
end

config :plausible, Plausible.ClickhouseRepo,
  loggers: [Ecto.LogEntry],
  queue_target: 500,
  queue_interval: 2000,
  url: ch_db_url

cond do
  config_env() == :prod ->
    base_cron = [
      # Daily at midnight
      {"0 0 * * *", Plausible.Tracking.Workers.RotateSalts}
    ]

    base_queues = [
      rotate_salts: 1
    ]

    # Keep 30 days history
    config :plausible, Oban,
      repo: Plausible.Repo,
      plugins: [{Oban.Plugins.Pruner, max_age: 2_592_000}],
      queues: base_queues,
      crontab: base_cron

  config_env() == :test ->
    config :plausible, Oban,
      repo: Plausible.Repo,
      testing: :inline

  true ->
    config :plausible, Oban,
      repo: Plausible.Repo,
      queues: [google_analytics_imports: 1],
      plugins: []
end

config :plausible, :user_agent_cache,
  limit: user_agent_cache_limit,
  stats: user_agent_cache_stats

if geonames_source_file do
  config :location, :geonames_source_file, geonames_source_file
end

config :ua_inspector,
  database_path: Application.app_dir(:plausible, "priv/ua_inspector")

config :ref_inspector,
  database_path: Application.app_dir(:plausible, "priv/ref_inspector")

config :logger,
  level: :info,
  backends: [:console]

config :logger, Sentry.LoggerBackend,
  capture_log_messages: true,
  level: :error,
  excluded_domains: []

config :tzdata,
       :data_dir,
       get_var_from_path_or_env(config_dir, "STORAGE_DIR", Application.app_dir(:tzdata, "priv"))

# OpenTelemetry configuration for Datadog
config :opentelemetry, :resource,
  service: %{
    name: System.get_env("OTEL_SERVICE_NAME", "careers-analytics"),
    version: System.get_env("DD_VERSION") || "unknown"
  }

# OpenTelemetry OTLP exporter configuration
otlp_endpoint = System.get_env("OTLP_COLLECTOR_URL", "http://datadog-otlp-collector:4318")

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter:
      {:opentelemetry_exporter,
       %{
         protocol: :grpc,
         endpoints: [otlp_endpoint]
       }}
  }
