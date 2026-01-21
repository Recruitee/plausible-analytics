defmodule Plausible.Test.SessionHelpers do
  @moduledoc """
  Helper functions for session-related tests.
  """

  alias Plausible.Session
  alias Plausible.ClickhouseRepo

  @test_domain "example.com"

  def build_session(attrs \\ %{}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    default_attrs = %{
      sign: 1,
      session_id: Enum.random(1..1_000_000_000),
      user_id: Enum.random(1..1_000_000_000),
      hostname: "test.example.com",
      domain: @test_domain,
      site_id: Enum.random(1..1_000_000),
      entry_page: "/",
      exit_page: "/",
      is_bounce: false,
      pageviews: 1,
      events: 1,
      duration: 0,
      start: now,
      timestamp: now,
      referrer: "",
      referrer_source: "",
      utm_medium: "",
      utm_source: "",
      utm_campaign: "",
      utm_content: "",
      utm_term: "",
      country_code: "",
      subdivision1_code: "",
      subdivision2_code: "",
      city_geoname_id: 0,
      screen_size: "Desktop",
      operating_system: "Mac",
      operating_system_version: "10.15",
      browser: "Chrome",
      browser_version: "91.0"
    }

    struct(Session, Map.merge(default_attrs, attrs))
  end

  def count_sessions_in_db(entry_page) do
    query = """
    SELECT count(*)
    FROM sessions
    WHERE domain = '#{@test_domain}'
      AND entry_page = '#{entry_page}'
    """

    case ClickhouseRepo.query(query) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  def get_session_from_db(session_id) do
    query = """
    SELECT entry_page, exit_page, pageviews, events, duration, referrer_source, utm_campaign, country_code, browser
    FROM sessions
    WHERE domain = '#{@test_domain}'
      AND session_id = #{session_id}
    LIMIT 1
    """

    case ClickhouseRepo.query(query) do
      {:ok,
       %{
         rows: [
           [
             entry_page,
             exit_page,
             pageviews,
             events,
             duration,
             referrer_source,
             utm_campaign,
             country_code,
             browser
           ]
         ]
       }} ->
        %{
          entry_page: entry_page,
          exit_page: exit_page,
          pageviews: pageviews,
          events: events,
          duration: duration,
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

  def cleanup_sessions do
    truncate_sessions_query = "TRUNCATE TABLE sessions;"

    {:ok, _} = ClickhouseRepo.query(truncate_sessions_query)
  end
end
