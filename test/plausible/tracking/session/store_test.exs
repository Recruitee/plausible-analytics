defmodule Plausible.Session.StoreTest do
  use Plausible.DataCase, async: false
  alias Plausible.Session.{Store, WriteBuffer}

  setup do
    buffer = Double.stub(WriteBuffer, :insert, fn _sessions -> nil end)

    {:ok, store} = GenServer.start_link(Store, buffer: buffer)
    [store: store, buffer: buffer]
  end

  test "creates a session from an event", %{store: store} do
    event =
      build(:event,
        name: "pageview",
        referrer: "ref",
        referrer_source: "refsource",
        utm_medium: "medium",
        utm_source: "source",
        utm_campaign: "campaign",
        utm_content: "content",
        utm_term: "term",
        browser: "browser",
        browser_version: "55",
        country_code: "EE",
        screen_size: "Desktop",
        operating_system: "Mac",
        operating_system_version: "11",
        campaign_id: 1,
        product_id: 1
      )

    Store.on_event(event, nil, store)

    assert_receive({WriteBuffer, :insert, [[session]]})

    assert session.hostname == event.hostname
    assert session.domain == event.domain
    assert session.user_id == event.user_id
    assert session.entry_page == event.pathname
    assert session.exit_page == event.pathname
    assert session.is_bounce == 1
    assert session.duration == 0
    assert session.pageviews == 1
    assert session.events == 1
    assert session.referrer == event.referrer
    assert session.referrer_source == event.referrer_source
    assert session.utm_medium == event.utm_medium
    assert session.utm_source == event.utm_source
    assert session.utm_campaign == event.utm_campaign
    assert session.utm_content == event.utm_content
    assert session.utm_term == event.utm_term
    assert session.country_code == event.country_code
    assert session.screen_size == event.screen_size
    assert session.operating_system == event.operating_system
    assert session.operating_system_version == event.operating_system_version
    assert session.campaign_id == event.campaign_id
    assert session.product_id == event.product_id
    assert session.browser == event.browser
    assert session.browser_version == event.browser_version
    assert session.timestamp == event.timestamp
    assert session.start === event.timestamp
  end

  test "updates a session", %{store: store} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

    event2 =
      build(:event,
        domain: event1.domain,
        user_id: event1.user_id,
        name: "pageview",
        timestamp: timestamp,
        country_code: "US",
        subdivision1_code: "SUB1",
        subdivision2_code: "SUB2",
        city_geoname_id: 12312,
        screen_size: "Desktop",
        operating_system: "Mac",
        operating_system_version: "11",
        browser: "Firefox",
        browser_version: "10"
      )

    Store.on_event(event1, nil, store)
    Store.on_event(event2, nil, store)

    assert_receive({WriteBuffer, :insert, [[session, _negative_record]]})

    assert session.is_bounce == 0
    assert session.duration == 10
    assert session.pageviews == 2
    assert session.events == 2
    assert session.country_code == "US"
    assert session.subdivision1_code == "SUB1"
    assert session.subdivision2_code == "SUB2"
    assert session.city_geoname_id == 12312
    assert session.operating_system == "Mac"
    assert session.operating_system_version == "11"
    assert session.browser == "Firefox"
    assert session.browser_version == "10"
    assert session.screen_size == "Desktop"
  end

  test "calculates duration correctly for out-of-order events", %{store: store} do
    timestamp = Timex.now()
    event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: 10))

    event2 =
      build(:event,
        domain: event1.domain,
        user_id: event1.user_id,
        name: "pageview",
        timestamp: timestamp
      )

    Store.on_event(event1, nil, store)
    Store.on_event(event2, nil, store)

    assert_receive({WriteBuffer, :insert, [[session, _negative_record]]})
    assert session.duration == 10
  end

  describe "session expiry" do
    test "creates new session when previous session has expired", %{store: store} do
      timestamp = Timex.now()
      # Session length is 30 minutes (1800 seconds)
      event1 =
        build(:event,
          name: "pageview",
          timestamp: timestamp |> Timex.shift(seconds: -1900)
        )

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})

      Store.on_event(event2, nil, store)
      assert_receive({WriteBuffer, :insert, [[session2]]})

      assert session1.session_id != session2.session_id
      assert session1.is_bounce == 1
      assert session2.is_bounce == 1
      assert session2.duration == 0
    end

    test "updates session when event is just within session timeout", %{store: store} do
      timestamp = Timex.now()
      # Just under 30 minutes (1799 seconds)
      event1 =
        build(:event,
          name: "pageview",
          timestamp: timestamp |> Timex.shift(seconds: -1799)
        )

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})

      Store.on_event(event2, nil, store)
      assert_receive({WriteBuffer, :insert, [[session2, negative_record]]})

      assert session1.session_id == negative_record.session_id
      assert session2.session_id == session1.session_id
      assert session2.is_bounce == 0
      assert session2.duration == 1799
    end
  end

  describe "user ID migration" do
    test "tracks session when user_id changes", %{store: store} do
      timestamp = Timex.now()
      old_user_id = 12345
      new_user_id = 67890

      event1 =
        build(:event,
          name: "pageview",
          user_id: old_user_id,
          timestamp: timestamp |> Timex.shift(seconds: -10)
        )

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: new_user_id,
          name: "pageview",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})

      Store.on_event(event2, old_user_id, store)
      assert_receive({WriteBuffer, :insert, [[session2, negative_record]]})

      assert session2.user_id == new_user_id
      assert session2.session_id == session1.session_id
      assert session2.is_bounce == 0
      assert negative_record.session_id == session1.session_id
    end

    test "creates new session when prev_user_id session is expired", %{store: store} do
      timestamp = Timex.now()
      old_user_id = 12345
      new_user_id = 67890

      event1 =
        build(:event,
          name: "pageview",
          user_id: old_user_id,
          timestamp: timestamp |> Timex.shift(seconds: -1900)
        )

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: new_user_id,
          name: "pageview",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})

      Store.on_event(event2, old_user_id, store)
      assert_receive({WriteBuffer, :insert, [[session2]]})

      assert session2.session_id != session1.session_id
      assert session2.user_id == new_user_id
      assert session2.is_bounce == 1
    end
  end

  describe "session attributes" do
    test "entry page is preserved on session updates", %{store: store} do
      timestamp = Timex.now()

      event1 =
        build(:event,
          name: "pageview",
          pathname: "/home",
          timestamp: timestamp |> Timex.shift(seconds: -10)
        )

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          pathname: "/about",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})
      assert session1.entry_page == "/home"
      assert session1.exit_page == "/home"

      Store.on_event(event2, nil, store)
      assert_receive({WriteBuffer, :insert, [[session2, _negative_record]]})

      assert session2.entry_page == "/home"
      assert session2.exit_page == "/about"
    end

    test "returns correct session_id", %{store: store} do
      event = build(:event, name: "pageview")
      session_id = Store.on_event(event, nil, store)

      assert_receive({WriteBuffer, :insert, [[session]]})
      assert session_id == session.session_id
      assert is_integer(session_id)
    end

    test "sign field is set correctly for new and updated sessions", %{store: store} do
      timestamp = Timex.now()
      event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          timestamp: timestamp
        )

      Store.on_event(event1, nil, store)
      assert_receive({WriteBuffer, :insert, [[session1]]})
      assert session1.sign == 1

      Store.on_event(event2, nil, store)
      assert_receive({WriteBuffer, :insert, [[new_session, negative_record]]})
      assert new_session.sign == 1
      assert negative_record.sign == -1
    end
  end

  describe "reconcile_event/2" do
    test "reconciles event without using GenServer" do
      timestamp = Timex.now()
      event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -10))

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          timestamp: timestamp
        )

      sessions = %{}
      sessions = Store.reconcile_event(sessions, event1)

      session_key = {event1.domain, event1.user_id}
      assert Map.has_key?(sessions, session_key)
      assert sessions[session_key].is_bounce == 1
      assert sessions[session_key].pageviews == 1

      sessions = Store.reconcile_event(sessions, event2)
      assert sessions[session_key].is_bounce == 0
      assert sessions[session_key].pageviews == 2
      assert sessions[session_key].duration == 10
    end

    test "reconcile_event creates new session when expired" do
      timestamp = Timex.now()

      event1 =
        build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -1900))

      event2 =
        build(:event,
          domain: event1.domain,
          user_id: event1.user_id,
          name: "pageview",
          timestamp: timestamp
        )

      sessions = %{}
      sessions = Store.reconcile_event(sessions, event1)
      session1 = sessions[{event1.domain, event1.user_id}]

      sessions = Store.reconcile_event(sessions, event2)
      session2 = sessions[{event2.domain, event2.user_id}]

      assert session1.session_id != session2.session_id
    end
  end

  describe "garbage collection" do
    test "removes old sessions from memory", %{store: store} do
      timestamp = Timex.now()
      # Session length is 30 min, forget_after is 60 min (3600 sec)
      old_event =
        build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -3700))

      recent_event = build(:event, name: "pageview", timestamp: timestamp)

      Store.on_event(old_event, nil, store)
      Store.on_event(recent_event, nil, store)

      assert_receive({WriteBuffer, :insert, [_]})
      assert_receive({WriteBuffer, :insert, [_]})

      state = :sys.get_state(store)
      initial_count = map_size(state.sessions)
      assert initial_count == 2

      send(store, :garbage_collect)

      Process.sleep(100)

      state = :sys.get_state(store)
      final_count = map_size(state.sessions)

      assert final_count == 1
    end

    test "preserves recent sessions during garbage collection", %{store: store} do
      timestamp = Timex.now()
      event1 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -100))
      event2 = build(:event, name: "pageview", timestamp: timestamp |> Timex.shift(seconds: -50))

      Store.on_event(event1, nil, store)
      Store.on_event(event2, nil, store)

      assert_receive({WriteBuffer, :insert, [_]})
      assert_receive({WriteBuffer, :insert, [_]})

      send(store, :garbage_collect)
      Process.sleep(100)

      state = :sys.get_state(store)
      assert map_size(state.sessions) == 2
    end
  end
end
