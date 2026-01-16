defmodule Plausible.Test.EventHelpers do
  @moduledoc """
  Helper functions for event-related tests.
  """

  alias Plausible.Event
  alias Plausible.Event.WriteBuffer
  alias Plausible.ClickhouseRepo

  @test_domain "event-write-buffer-test.com"

  def build_event(attrs \\ %{}) do
    default_attrs = %{
      name: "pageview",
      domain: @test_domain,
      site_id: Enum.random(1..1_000_000),
      hostname: @test_domain,
      pathname: "/test-page",
      user_id: Enum.random(1..1_000_000_000),
      session_id: Enum.random(1..1_000_000_000),
      timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }

    struct(Event, Map.merge(default_attrs, attrs))
  end

  def count_events_in_db(pathname) do
    query = """
    SELECT count(*)
    FROM events
    WHERE domain = '#{@test_domain}'
      AND pathname = '#{pathname}'
    """

    case ClickhouseRepo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  def get_event_from_db(user_id) do
    query = """
    SELECT name, pathname, referrer_source, utm_campaign, country_code, browser
    FROM events
    WHERE domain = '#{@test_domain}'
      AND user_id = #{user_id}
    LIMIT 1
    """

    case ClickhouseRepo.query(query) do
      {:ok, %{rows: [[name, pathname, referrer_source, utm_campaign, country_code, browser]]}} ->
        %{
          name: name,
          pathname: pathname,
          referrer_source: referrer_source,
          utm_campaign: utm_campaign,
          country_code: country_code,
          browser: browser
        }

      _ ->
        nil
    end
  end

  def wait_time_ms, do: 250

  def cleanup_events do
    truncate_events_query = "TRUNCATE TABLE events;"

    {:ok, _} = ClickhouseRepo.query(truncate_events_query)
  end

  def flush_and_cleanup do
    :ok = WriteBuffer.flush()
    Process.sleep(wait_time_ms())

    cleanup_events()
  end
end
