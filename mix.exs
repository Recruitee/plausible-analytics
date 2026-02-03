defmodule Plausible.MixProject do
  use Mix.Project

  def project do
    [
      app: :plausible,
      version: System.get_env("APP_VERSION", "0.0.1"),
      elixir: "~> 1.17.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
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
      {:cachex, "~> 4.1"},
      {:cors_plug, "~> 3.0"},
      {:ecto_ch, "~> 0.8.0"},
      {:ecto_sql, "~> 3.13"},
      {:envy, "~> 1.1.1"},
      {:httpoison, "~> 1.4"},
      {:jason, "~> 1.3", override: true},
      {:location, git: "https://github.com/plausible/location.git", ref: "0c3b18a"},
      {:locus, "~> 2.3.10"},
      {:oban, "~> 2.19"},
      {:open_telemetry_decorator, "~> 1.5"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_oban, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.1", override: true},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_view, "~> 2.0"},
      {:plug, "~> 1.18", override: true},
      {:plug_cowboy, "~> 2.6"},
      {:postgrex, ">= 0.0.0", override: true},
      {:public_sufx, "~> 0.6"},
      {:ref_inspector, "~> 2.1"},
      {:referrer_blocklist,
       git: "https://github.com/plausible/referrer-blocklist.git", ref: "d6f52c2"},
      {:sentry, "~> 10.9"},
      {:siphash, "~> 3.2"},
      {:telemetry, "~> 1.0", override: true},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_statsd, "~> 0.6"},
      {:timex, "~> 3.7"},
      {:tzdata, "~> 1.1.2"},
      {:ua_inspector, "~> 3.11"},

      # Dev only dependencies
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.5", only: :dev},

      # Test only dependencies
      {:double, "~> 0.8.0", only: :test},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:ex_machina, "~> 2.3", only: :test},
      {:mox, "~> 1.0", only: :test}
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
