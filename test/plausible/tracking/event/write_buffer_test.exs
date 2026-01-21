defmodule Plausible.Event.WriteBufferTest do
  use Plausible.DataCase, async: false

  import Plausible.Test.EventHelpers
  import Plausible.TestUtils, only: [get_buffer_size: 0, get_flush_interval_ms: 0]

  alias Plausible.Event.WriteBuffer

  setup do
    flush_and_cleanup()

    on_exit(fn -> flush_and_cleanup() end)
    :ok
  end

  describe "flush via buffer" do
    test "automatically flushes when buffer exceeds its size" do
      buffer_size = get_buffer_size()

      Enum.each(1..(buffer_size + 1), fn i ->
        WriteBuffer.insert(build_event(%{pathname: "/buffer-size-test", user_id: i}))
      end)

      # Wait for flush in background to fully complete
      Process.sleep(wait_time_ms())

      assert buffer_size == count_events_in_db("/buffer-size-test")
    end
  end

  describe "timer interval flush" do
    test "automatically flushes after flush_interval_ms elapses" do
      flush_interval = get_flush_interval_ms()
      buffer_size = get_buffer_size()

      event_count = div(buffer_size, 10)

      Enum.each(1..event_count, fn i ->
        WriteBuffer.insert(build_event(%{pathname: "/timer-interval-test", user_id: i}))
      end)

      assert count_events_in_db("/timer-interval-test") == 0
      # Wait for timer interval + flush in background to fully complete
      Process.sleep(flush_interval + wait_time_ms())

      assert event_count == count_events_in_db("/timer-interval-test")
    end

    test "timer resets after manual flush" do
      flush_interval = get_flush_interval_ms()

      WriteBuffer.insert(build_event(%{pathname: "/timer-reset-test", user_id: 1}))
      WriteBuffer.flush()

      # Wait for flush in background to fully complete
      Process.sleep(wait_time_ms())

      assert count_events_in_db("/timer-reset-test") == 1

      WriteBuffer.insert(build_event(%{pathname: "/timer-reset-test", user_id: 2}))

      # Wait for timer interval + flush in background to fully complete
      Process.sleep(flush_interval + wait_time_ms())

      count = count_events_in_db("/timer-reset-test")

      assert count == 2
    end
  end

  describe "manual flush" do
    test "flush/0 immediately persists buffered events to ClickHouse" do
      Enum.each(1..5, fn i ->
        WriteBuffer.insert(build_event(%{pathname: "/manual-flush-test", user_id: i}))
      end)

      assert count_events_in_db("/manual-flush-test") == 0

      assert :ok = WriteBuffer.flush()

      count = count_events_in_db("/manual-flush-test")

      assert count == 5
    end
  end

  describe "event data integrity" do
    test "persists all event fields correctly" do
      unique_id = :rand.uniform(1_000_000_000)

      event =
        build_event(%{
          name: "custom_event",
          pathname: "/integrity-test",
          user_id: unique_id,
          referrer: "https://google.com/search",
          referrer_source: "Google",
          utm_medium: "cpc",
          utm_source: "google_ads",
          utm_campaign: "winter_sale",
          utm_content: "ad_variant_b",
          utm_term: "blue_widgets",
          country_code: "DE",
          subdivision1_code: "DE-BE",
          city_geoname_id: 2_950_159,
          screen_size: "Desktop",
          operating_system: "Windows",
          operating_system_version: "11",
          browser: "Firefox",
          browser_version: "105.0"
        })

      WriteBuffer.insert(event)
      :ok = WriteBuffer.flush()

      persisted_event = get_event_from_db(unique_id)

      assert persisted_event != nil
      assert persisted_event.name == "custom_event"
      assert persisted_event.pathname == "/integrity-test"
      assert persisted_event.referrer_source == "Google"
      assert persisted_event.utm_campaign == "winter_sale"
      assert persisted_event.country_code == "DE"
      assert persisted_event.browser == "Firefox"
    end
  end
end
