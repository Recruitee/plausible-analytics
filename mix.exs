defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      app: :plausible,
      version: System.get_env("APP_VERSION", "0.0.1"),
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ],
      releases: [
        plausible: [
          include_executables_for: [:unix],
          applications: [plausible: :permanent, opentelemetry: :temporary],
          steps: [:assemble, :tar]
        ]
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Plausible.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 2.0"},
      {:cors_plug, "~> 2.0"},
      {:ecto_sql, "< 3.7.2"},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:jason, "~> 1.3", override: true},
      {:phoenix, "~> 1.6.16"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 3.3", override: true},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug, "~> 1.14", override: true},
      {:plug_cowboy, "~> 2.6"},
      {:postgrex, ">= 0.0.0", override: true},
      {:ref_inspector, "~> 1.3"},
      {:timex, "~> 3.7"},
      {:tzdata, "~> 1.1.2"},
      {:gettext, "~> 0.20.0", override: true},
      {:ua_inspector, "~> 2.2"},
      {:hackney, "~> 1.18"},
      {:sentry, "~> 8.0"},
      {:httpoison, "~> 1.4"},
      {:ex_machina, "~> 2.3", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:double, "~> 0.8.0", only: :test},
      {:csv, "~> 2.3"},
      {:siphash, "~> 3.2"},
      {:oban, "~> 2.12.0"},
      {:locus, "~> 2.3.10"},
      {:clickhouse_ecto, git: "https://github.com/Recruitee/clickhouse_ecto.git", ref: "ed45cd0"},
      {:location, git: "https://github.com/plausible/location.git"},
      {:cachex, "~> 3.4"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:envy, "~> 1.1.1"},
      {:phoenix_pagination, "~> 0.7.0"},
      {:public_suffix, git: "https://github.com/axelson/publicsuffix-elixir"},
      {:telemetry, "~> 1.0", override: true},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_statsd, "~> 0.6"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:open_telemetry_decorator, "~> 1.4.6"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:opentelemetry_oban, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:floki, "~> 0.32.0", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:referrer_blocklist,
       git: "https://github.com/plausible/referrer-blocklist.git", ref: "d6f52c2"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test", "clean_clickhouse"],
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end
end
