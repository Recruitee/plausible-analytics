defmodule Plausible.Session.WriteBuffer do
  use GenServer
  require Logger
  use OpenTelemetryDecorator

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(buffer) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms())
    {:ok, %{buffer: buffer, timer: timer, last_flush_time: System.monotonic_time()}}
  end

  @decorate trace("ingest.session.insert")
  def insert(sessions) do
    GenServer.cast(__MODULE__, {:insert, sessions})
    {:ok, sessions}
  end

  def handle_cast({:insert, sessions}, %{buffer: buffer} = state) do
    new_buffer = sessions ++ buffer
    new_buffer_size = length(new_buffer)
    session_count = length(sessions)

    :telemetry.execute(
      [:plausible, :ingest, :buffer, :session, :insert],
      %{count: session_count, buffer_size: new_buffer_size},
      %{}
    )

    if new_buffer_size >= buffer_size() do
      Logger.info("Buffer full, flushing to disk")
      Process.cancel_timer(state[:timer])
      new_last_flush_time = flush(new_buffer, :buffer_full, state.last_flush_time)
      new_timer = Process.send_after(self(), :tick, flush_interval_ms())
      {:noreply, %{buffer: [], timer: new_timer, last_flush_time: new_last_flush_time}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:tick, %{buffer: buffer, last_flush_time: last_flush_time}) do
    new_last_flush_time = flush(buffer, :timer, last_flush_time)
    timer = Process.send_after(self(), :tick, flush_interval_ms())
    {:noreply, %{buffer: [], timer: timer, last_flush_time: new_last_flush_time}}
  end

  def terminate(_reason, %{buffer: buffer, last_flush_time: last_flush_time}) do
    Logger.info("Flushing session buffer before shutdown...")
    flush(buffer, :shutdown, last_flush_time)
  end

  @decorate trace("ingest.session.flush")
  defp flush(buffer, trigger, last_flush_time) do
    buffer_size = length(buffer)
    current_time = System.monotonic_time()

    time_since_last_flush =
      System.convert_time_unit(
        current_time - last_flush_time,
        :native,
        :millisecond
      )

    flush_start = System.monotonic_time()

    case buffer do
      [] ->
        nil

      sessions ->
        Logger.info("Flushing #{buffer_size} sessions (trigger: #{trigger})")

        sessions =
          sessions
          |> Enum.map(&(Map.from_struct(&1) |> Map.delete(:__meta__)))
          |> Enum.reverse()

        Plausible.ClickhouseRepo.insert_all(Plausible.Session, sessions)
    end

    flush_duration = System.monotonic_time() - flush_start

    :telemetry.execute(
      [:plausible, :ingest, :buffer, :session, :flush],
      %{
        count: buffer_size,
        duration: flush_duration,
        time_since_last_flush: time_since_last_flush
      },
      %{trigger: trigger}
    )

    current_time
  end

  defp flush_interval_ms() do
    Keyword.fetch!(Application.get_env(:plausible, :ingestion), :flush_interval_ms)
  end

  defp buffer_size() do
    Keyword.fetch!(Application.get_env(:plausible, :ingestion), :buffer_size)
  end
end
