defmodule Plausible.Telemetry do
  @moduledoc """
  Telemetry metrics supervisor for Plausible.

  Defines and exports metrics to Datadog via StatsD for monitoring
  buffer performance, throughput, and operational health.

  ## Configuration

  - In production: Uses StatsD reporter (Datadog)
  - In test: Telemetry is disabled to avoid flooding test output
  - In dev: Console reporter is disabled by default. To enable it for debugging:

      config :plausible, telemetry_console_reporter: true
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      case Application.get_env(:plausible, :env) do
        :test ->
          # No telemetry in tests to avoid flooding test output
          []

        :dev ->
          # Console reporter only if explicitly enabled via config
          if Application.get_env(:plausible, :telemetry_console_reporter, false) do
            [{Plausible.Telemetry.ConsoleReporter, metrics: metrics()}]
          else
            []
          end

        _ ->
          # StatsD reporter for production (Datadog)
          [Plausible.Telemetry.DatadogStatsd.child_spec(:prod)]
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Defines all telemetry metrics for WriteBuffer monitoring.

  Metrics are sent to Datadog StatsD and include:
  - Counters: Total inserts and flushes
  - Gauges: Current buffer size and utilization
  - Distributions: Flush sizes, durations, and intervals
  """
  def metrics do
    [
      # ============================================================
      # INSERT METRICS
      # ============================================================

      # Total number of items inserted (counter)
      counter("careers_analytics.event.insert.count",
        event_name: [:plausible, :ingest, :buffer, :event, :insert],
        measurement: :count,
        description: "Total number of events inserted into buffer",
        tags: [:buffer_type],
        tag_values: fn _meta -> %{buffer_type: "event"} end
      ),

      counter("careers_analytics.session.insert.count",
        event_name: [:plausible, :ingest, :buffer, :session, :insert],
        measurement: :count,
        description: "Total number of sessions inserted into buffer",
        tags: [:buffer_type],
        tag_values: fn _meta -> %{buffer_type: "session"} end
      ),

      # Current buffer size after insert (gauge)
      last_value("careers_analytics.event.buffer_size",
        event_name: [:plausible, :ingest, :buffer, :event, :insert],
        measurement: :buffer_size,
        description: "Current event buffer size",
        tags: [:buffer_type],
        tag_values: fn _meta -> %{buffer_type: "event"} end
      ),

      last_value("careers_analytics.session.buffer_size",
        event_name: [:plausible, :ingest, :buffer, :session, :insert],
        measurement: :buffer_size,
        description: "Current session buffer size",
        tags: [:buffer_type],
        tag_values: fn _meta -> %{buffer_type: "session"} end
      ),

      # ============================================================
      # FLUSH METRICS
      # ============================================================

      # Total number of flushes by trigger type (counter)
      counter("careers_analytics.event.flush.total",
        event_name: [:plausible, :ingest, :buffer, :event, :flush],
        measurement: fn _measurements -> 1 end,
        description: "Total number of event buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end
      ),

      counter("careers_analytics.session.flush.total",
        event_name: [:plausible, :ingest, :buffer, :session, :flush],
        measurement: fn _measurements -> 1 end,
        description: "Total number of session buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end
      ),

      # Flush size distribution (histogram)
      distribution("careers_analytics.event.flush.size",
        event_name: [:plausible, :ingest, :buffer, :event, :flush],
        measurement: :count,
        description: "Distribution of event flush batch sizes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end,
        unit: :unit
      ),

      distribution("careers_analytics.session.flush.size",
        event_name: [:plausible, :ingest, :buffer, :session, :flush],
        measurement: :count,
        description: "Distribution of session flush batch sizes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end,
        unit: :unit
      ),

      # Flush duration distribution (histogram in milliseconds)
      distribution("careers_analytics.event.flush.duration_ms",
        event_name: [:plausible, :ingest, :buffer, :event, :flush],
        measurement: :duration,
        description: "Event flush duration distribution",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        ]
      ),

      distribution("careers_analytics.session.flush.duration_ms",
        event_name: [:plausible, :ingest, :buffer, :session, :flush],
        measurement: :duration,
        description: "Session flush duration distribution",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        ]
      ),

      # Time between flushes distribution (histogram in milliseconds)
      distribution("careers_analytics.event.flush.interval_ms",
        event_name: [:plausible, :ingest, :buffer, :event, :flush],
        measurement: :time_since_last_flush,
        description: "Time between event buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end,
        unit: :millisecond,
        reporter_options: [
          buckets: [100, 500, 1000, 2000, 5000, 10000, 30000, 60000]
        ]
      ),

      distribution("careers_analytics.session.flush.interval_ms",
        event_name: [:plausible, :ingest, :buffer, :session, :flush],
        measurement: :time_since_last_flush,
        description: "Time between session buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end,
        unit: :millisecond,
        reporter_options: [
          buckets: [100, 500, 1000, 2000, 5000, 10000, 30000, 60000]
        ]
      ),

      # Buffer utilization percentage (gauge - calculated in handler)
      summary("careers_analytics.event.utilization_percent",
        event_name: [:plausible, :ingest, :buffer, :event, :utilization],
        measurement: :utilization,
        description: "Event buffer utilization percentage",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end,
        unit: :percent
      ),

      summary("careers_analytics.session.utilization_percent",
        event_name: [:plausible, :ingest, :buffer, :session, :utilization],
        measurement: :utilization,
        description: "Session buffer utilization percentage",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end,
        unit: :percent
      ),

      # Empty flush counter (emitted by handler)
      counter("careers_analytics.event.empty_flushes",
        event_name: [:plausible, :ingest, :buffer, :event, :empty_flush],
        measurement: fn _measurements -> 1 end,
        description: "Number of empty event buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "event", trigger: meta.trigger} end
      ),

      counter("careers_analytics.session.empty_flushes",
        event_name: [:plausible, :ingest, :buffer, :session, :empty_flush],
        measurement: fn _measurements -> 1 end,
        description: "Number of empty session buffer flushes",
        tags: [:buffer_type, :trigger],
        tag_values: fn meta -> %{buffer_type: "session", trigger: meta.trigger} end
      )
    ]
  end
end
