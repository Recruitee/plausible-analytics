defmodule Plausible.Tracking.BufferTelemetry do
  @moduledoc """
  Telemetry event handlers for WriteBuffer metrics collection.

  Tracks buffer performance, health, and utilization for Event and Session buffers.
  Emits additional derived metrics for TelemetryMetricsStatsd integration with Datadog.
  """

  require Logger

  @doc """
  Attaches all telemetry handlers for buffer monitoring.
  Called during application startup in Plausible.Application.
  """
  def setup do
    events = [
      [:plausible, :ingest, :buffer, :event, :insert],
      [:plausible, :ingest, :buffer, :event, :flush],
      [:plausible, :ingest, :buffer, :session, :insert],
      [:plausible, :ingest, :buffer, :session, :flush]
    ]

    :telemetry.attach_many(
      "plausible-buffer-metrics",
      events,
      &__MODULE__.handle_event/4,
      %{}
    )

    Logger.info("Buffer telemetry handlers attached")
  end

  @doc """
  Handles telemetry events and emits derived metrics.

  Logs metrics for observability and emits additional telemetry events
  for utilization percentage and empty flush tracking.
  """
  def handle_event([:plausible, :ingest, :buffer, type, :insert], measurements, _metadata, _config) do
    Logger.debug(
      "[Buffer] #{type} insert: count=#{measurements.count}, buffer_size=#{measurements.buffer_size}"
    )
  end

  def handle_event([:plausible, :ingest, :buffer, type, :flush], measurements, metadata, _config) do
    trigger = metadata.trigger
    count = measurements.count
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    time_since_last_ms = measurements.time_since_last_flush

    max_size = Application.get_env(:plausible, :ingestion)[:buffer_size]
    utilization = if max_size > 0, do: Float.round(count / max_size * 100, 1), else: 0

    # Emit utilization metric for TelemetryMetrics
    :telemetry.execute(
      [:plausible, :ingest, :buffer, type, :utilization],
      %{utilization: utilization},
      %{trigger: trigger}
    )

    # Emit empty flush metric if count is 0
    if count == 0 do
      :telemetry.execute(
        [:plausible, :ingest, :buffer, type, :empty_flush],
        %{},
        %{trigger: trigger}
      )
    end

    Logger.info(
      "[Buffer] #{type} flush: trigger=#{trigger}, count=#{count}, " <>
        "utilization=#{utilization}%, duration_ms=#{duration_ms}, time_since_last_ms=#{time_since_last_ms}"
    )
  end
end
