defmodule Plausible.Session.Store do
  use GenServer
  use Plausible.Repo
  require Logger

  @garbage_collect_interval_milliseconds 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    buffer = Keyword.get(opts, :buffer, Plausible.Session.WriteBuffer)
    timer = Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    {:ok, %{timer: timer, sessions: %{}, buffer: buffer}}
  end

  def on_event(event, prev_user_id, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_event, event, prev_user_id})
  end

  def handle_call(
        {:on_event, event, prev_user_id},
        _from,
        %{sessions: sessions, buffer: buffer} = state
      ) do
    session_key = {event.domain, event.user_id}

    found_session =
      sessions[session_key] || (prev_user_id && sessions[{event.domain, prev_user_id}])

    active = is_active?(found_session, event)

    updated_sessions =
      cond do
        found_session && active ->
          new_session = update_session(found_session, event)
          buffer.insert([%{new_session | sign: 1}, %{found_session | sign: -1}])
          Map.put(sessions, session_key, new_session)

        found_session && !active ->
          new_session = new_session_from_event(event)
          buffer.insert([new_session])
          Map.put(sessions, session_key, new_session)

        true ->
          new_session = new_session_from_event(event)
          buffer.insert([new_session])
          Map.put(sessions, session_key, new_session)
      end

    session_id = updated_sessions[session_key].session_id
    {:reply, session_id, %{state | sessions: updated_sessions}}
  end

  def reconcile_event(sessions, event) do
    session_key = {event.domain, event.user_id}
    found_session = sessions[session_key]
    active = is_active?(found_session, event)

    updated_sessions =
      cond do
        found_session && active ->
          new_session = update_session(found_session, event)
          Map.put(sessions, session_key, new_session)

        found_session && !active ->
          new_session = new_session_from_event(event)
          Map.put(sessions, session_key, new_session)

        true ->
          new_session = new_session_from_event(event)
          Map.put(sessions, session_key, new_session)
      end

    updated_sessions
  end

  defp is_active?(session, event) do
    session && Timex.diff(event.timestamp, session.timestamp, :second) < session_length_seconds()
  end

  defp update_session(session, event) do
    %{
      session
      | user_id: event.user_id,
        company_id: event.company_id,
        site_id: event.site_id,
        timestamp: event.timestamp,
        exit_page: event.pathname,
        is_bounce: 0,
        duration: Timex.diff(event.timestamp, session.start, :second) |> abs,
        pageviews: session.pageviews + if(event.name == "pageview", do: 1, else: 0),
        country_code: coalesce(event.country_code, session.country_code, ""),
        subdivision1_code: coalesce(event.subdivision1_code, session.subdivision1_code, ""),
        subdivision2_code: coalesce(event.subdivision2_code, session.subdivision2_code, ""),
        city_geoname_id: coalesce(event.city_geoname_id, session.city_geoname_id, 0),
        operating_system: coalesce(event.operating_system, session.operating_system, ""),
        operating_system_version:
          coalesce(event.operating_system_version, session.operating_system_version, ""),
        browser: coalesce(event.browser, session.browser, ""),
        browser_version: coalesce(event.browser_version, session.browser_version, ""),
        screen_size: coalesce(event.screen_size, session.screen_size, ""),
        events: session.events + 1
    }
  end

  defp new_session_from_event(event) do
    %Plausible.Session{
      sign: 1,
      company_id: event.company_id,
      site_id: event.site_id,
      session_id: Plausible.Session.random_uint64(),
      campaign_id: event.campaign_id,
      product_id: event.product_id,
      hostname: event.hostname,
      domain: event.domain,
      user_id: event.user_id,
      entry_page: event.pathname,
      exit_page: event.pathname,
      is_bounce: 1,
      duration: 0,
      pageviews: if(event.name == "pageview", do: 1, else: 0),
      events: 1,
      referrer: event.referrer,
      referrer_source: event.referrer_source,
      utm_medium: event.utm_medium,
      utm_source: event.utm_source,
      utm_campaign: event.utm_campaign,
      utm_content: event.utm_content,
      utm_term: event.utm_term,
      country_code: event.country_code,
      subdivision1_code: event.subdivision1_code,
      subdivision2_code: event.subdivision2_code,
      city_geoname_id: event.city_geoname_id,
      screen_size: event.screen_size,
      operating_system: event.operating_system,
      operating_system_version: event.operating_system_version,
      browser: event.browser,
      browser_version: event.browser_version,
      timestamp: event.timestamp,
      start: event.timestamp
    }
  end

  def handle_info(:garbage_collect, state) do
    Logger.debug("Session store collecting garbage")

    now = Timex.now()

    new_sessions =
      Enum.reduce(state[:sessions], %{}, fn {key, session}, acc ->
        if Timex.diff(now, session.timestamp, :second) <= forget_session_after() do
          Map.put(acc, key, session)
        else
          # forget the session
          acc
        end
      end)

    Process.cancel_timer(state[:timer])

    new_timer =
      Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    Logger.debug(fn ->
      n_old = Enum.count(state[:sessions])
      n_new = Enum.count(new_sessions)
      "Removed #{n_old - n_new} sessions from store"
    end)

    {:noreply, %{state | sessions: new_sessions, timer: new_timer}}
  end

  defp coalesce(nil, fallback, _default), do: fallback
  defp coalesce("", fallback, _default), do: fallback
  defp coalesce(value, _fallback, _default), do: value

  defp session_length_seconds(), do: Application.get_env(:plausible, :session_length_minutes) * 60
  defp forget_session_after(), do: session_length_seconds() * 2
end
