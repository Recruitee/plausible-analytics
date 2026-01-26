defmodule Plausible.Session.WriteBufferTest do
  use Plausible.DataCase

  import Plausible.Test.SessionHelpers
  import Plausible.TestUtils, only: [get_buffer_size: 0, get_flush_interval_ms: 0]

  alias Plausible.Session.WriteBuffer

  setup do
    cleanup_sessions()

    on_exit(fn -> cleanup_sessions() end)
    :ok
  end

  describe "flush via buffer" do
    test "automatically flushes when buffer exceeds its size" do
      buffer_size = get_buffer_size()

      sessions =
        for i <- 1..buffer_size do
          build_session(%{entry_page: "/buffer-test", user_id: i, session_id: i})
        end

      Enum.each(sessions, fn session ->
        WriteBuffer.insert([session])
      end)

      # Wait for timer interval + flush in background to fully complete
      Process.sleep(get_flush_interval_ms() + wait_time_ms())

      count = count_sessions_in_db("/buffer-test")
      assert count == buffer_size
    end
  end

  describe "timer interval flush" do
    test "automatically flushes after flush_interval_ms elapses" do
      buffer_size = get_buffer_size()
      session_count = div(buffer_size, 10)

      sessions =
        for i <- 1..session_count do
          build_session(%{entry_page: "/timer-test", user_id: i, session_id: i})
        end

      Enum.each(sessions, fn session ->
        WriteBuffer.insert([session])
      end)

      assert count_sessions_in_db("/timer-test") == 0

      # Wait for timer interval + flush in background to fully complete
      Process.sleep(get_flush_interval_ms() + wait_time_ms())

      assert session_count == count_sessions_in_db("/timer-test")
    end
  end

  describe "database persistence" do
    test "persists all session fields correctly" do
      unique_user_id = :rand.uniform(1_000_000_000)
      unique_session_id = :rand.uniform(1_000_000_000)

      session =
        build_session(%{
          domain: "example.com",
          entry_page: "/db-integrity-test",
          exit_page: "/db-integrity-exit",
          user_id: unique_user_id,
          session_id: unique_session_id,
          is_bounce: 0,
          pageviews: 7,
          events: 12,
          duration: 450,
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

      WriteBuffer.insert([session])

      # Wait for timer interval + flush in background to fully complete
      Process.sleep(get_flush_interval_ms() + wait_time_ms())

      persisted_session = get_session_from_db(unique_session_id)

      assert persisted_session != nil
      assert persisted_session.entry_page == "/db-integrity-test"
      assert persisted_session.exit_page == "/db-integrity-exit"
      assert persisted_session.pageviews == 7
      assert persisted_session.events == 12
      assert persisted_session.duration == 450
      assert persisted_session.referrer_source == "Google"
      assert persisted_session.utm_campaign == "winter_sale"
      assert persisted_session.country_code == "DE"
      assert persisted_session.browser == "Firefox"
    end
  end
end
