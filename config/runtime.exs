import Config

if config_env() == :prod do
  # we'd normally put here production runtime configuration but this app is not meant to be run as standalone prod application.
  # instead the missing configuration related to databases, endpoints etc is provided by the umbrella app that uses plausible as a dependency
end

config :ua_inspector,
  database_path: Application.app_dir(:plausible, "priv/ua_inspector")

config :ref_inspector,
  database_path: Application.app_dir(:plausible, "priv/ref_inspector")
