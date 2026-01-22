defmodule Plausible.Telemetry.DatadogStatsd do
  require Logger

  @moduledoc """
  Datadog StatsD telemetry reporter configuration.

  Provides Datadog-specific StatsD metric formatting and configuration,
  including global tags, hostname resolution, and metrics collection.
  """

  def child_spec(_env) do
    Supervisor.child_spec(
      TelemetryMetricsStatsd.child_spec(
        formatter: :datadog,
        host: host(),
        metrics: metrics(),
        global_tags: global_tags(),
        host_resolution_interval: :timer.minutes(5)
      ),
      id: :telemetry_datadog_statsd
    )
  end

  def host do
    hostname = System.get_env("DATADOG_AGENT_HOST", "datadog-agent.datadog.svc.cluster.local")

    case :inet.gethostbyname(to_charlist(hostname)) do
      {:ok, _} ->
        hostname

      {:error, err} ->
        Logger.warning(
          "[#{__MODULE__}] Unresolvable hostname given (#{hostname}, error: #{err}), falling back to localhost"
        )

        "localhost"
    end
  end

  def global_tags do
    [
      hostname: System.get_env("HOSTNAME", "unknown"),
      service: "careers-analytics",
      version: System.get_env("DD_VERSION", "unknown")
    ]
  end

  def metrics do
    Plausible.Telemetry.metrics()
  end
end
