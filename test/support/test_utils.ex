defmodule Plausible.TestUtils do
  use Plausible.Repo
  alias Plausible.Factory


  def create_pageviews(pageviews) do
    pageviews =
      Enum.map(pageviews, fn pageview ->
        Factory.build(:pageview, pageview) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("events", pageviews)
  end

  def create_events(events) do
    events =
      Enum.map(events, fn event ->
        Factory.build(:event, event) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("events", events)
  end

  def create_sessions(sessions) do
    sessions =
      Enum.map(sessions, fn session ->
        Factory.build(:ch_session, session) |> Map.from_struct() |> Map.delete(:__meta__)
      end)

    Plausible.ClickhouseRepo.insert_all("sessions", sessions)
  end

  def populate_stats(site, events) do
    Enum.map(events, fn event ->
      case event do
        %Plausible.ClickhouseEvent{} ->
          Map.put(event, :domain, site.domain)

        _ ->
          Map.put(event, :site_id, site.id)
      end
    end)
    |> populate_stats
  end

  def populate_stats(events) do
    {native, _imported} =
      Enum.split_with(events, fn event ->
        case event do
          %Plausible.ClickhouseEvent{} ->
            true

          _ ->
            false
        end
      end)

    if native, do: populate_native_stats(native)
  end

  defp populate_native_stats(events) do
    sessions =
      Enum.reduce(events, %{}, fn event, sessions ->
        Plausible.Session.Store.reconcile_event(sessions, event)
      end)

    events =
      Enum.map(events, fn event ->
        Map.put(event, :session_id, sessions[{event.domain, event.user_id}].session_id)
      end)

    Plausible.ClickhouseRepo.insert_all(
      Plausible.ClickhouseEvent,
      Enum.map(events, &schema_to_map/1)
    )

    Plausible.ClickhouseRepo.insert_all(
      Plausible.ClickhouseSession,
      Enum.map(Map.values(sessions), &schema_to_map/1)
    )
  end

  def relative_time(shifts) do
    NaiveDateTime.utc_now()
    |> Timex.shift(shifts)
    |> NaiveDateTime.truncate(:second)
  end

  defp schema_to_map(schema) do
    Map.from_struct(schema)
    |> Map.delete(:__meta__)
  end
end
