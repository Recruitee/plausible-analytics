defmodule Plausible.Telemetry.ConsoleReporter do
  @moduledoc """
  Console reporter for telemetry metrics.

  Prints metrics to console for local development and testing.
  Useful for verifying telemetry is working without needing Datadog.
  """

  use GenServer
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(config) do
    metrics = Keyword.fetch!(config, :metrics)

    for metric <- metrics do
      event_name = metric.event_name

      :telemetry.attach(
        handler_id(metric),
        event_name,
        &__MODULE__.handle_event/4,
        metric
      )
    end

    Logger.info("Console telemetry reporter attached to #{length(metrics)} metrics")
    {:ok, %{}}
  end

  def handle_event(_event_name, measurements, metadata, metric) do
    # metric.name is a list of atoms like [:event, :insert, :count]
    metric_name = metric.name |> Enum.join(".")
    metric_type = metric.__struct__ |> Module.split() |> List.last()

    # Extract the measurement value
    value =
      case metric.measurement do
        fun when is_function(fun) -> fun.(measurements)
        key when is_atom(key) -> Map.get(measurements, key)
        _ -> measurements
      end

    # Format tags
    tags =
      case metric do
        %{tag_values: tag_values_fn} when is_function(tag_values_fn) ->
          tag_values_fn.(metadata)

        %{tags: tags} when is_list(tags) ->
          for tag <- tags, into: %{} do
            {tag, Map.get(metadata, tag, "unknown")}
          end

        _ ->
          %{}
      end

    tag_string =
      if map_size(tags) > 0 do
        tags
        |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
        |> Enum.join(", ")
        |> then(&" [#{&1}]")
      else
        ""
      end

    Logger.info(
      "[Telemetry] #{metric_type} #{metric_name} = #{format_value(value, metric)}#{tag_string}"
    )
  end

  defp format_value(value, %{unit: {:native, :millisecond}}) when is_integer(value) do
    ms = System.convert_time_unit(value, :native, :millisecond)
    "#{ms}ms"
  end

  defp format_value(value, %{unit: :millisecond}) when is_number(value) do
    "#{value}ms"
  end

  defp format_value(value, %{unit: :percent}) when is_number(value) do
    "#{value}%"
  end

  defp format_value(value, _metric) when is_number(value) do
    "#{value}"
  end

  defp format_value(value, _metric) do
    inspect(value)
  end

  defp handler_id(metric) do
    # metric.name is a list of atoms, convert to string for handler ID
    name_string = metric.name |> Enum.join(".")
    "console-reporter-#{name_string}"
  end
end
