defmodule Plausible.Factory do
  use ExMachina.Ecto, repo: Plausible.Repo

  def user_factory(attrs) do
    pw = Map.get(attrs, :password, "password")

    user = %Plausible.Auth.User{
      name: "Jane Smith",
      email: sequence(:email, &"email-#{&1}@example.com"),
      password_hash: Plausible.Auth.Password.hash(pw),
      trial_expiry_date: Timex.today() |> Timex.shift(days: 30),
      email_verified: true
    }

    merge_attributes(user, attrs)
  end

  def site_factory do
    domain = sequence(:domain, &"example-#{&1}.com")

    %Plausible.Site{
      domain: domain,
      timezone: "UTC"
    }
  end

  def site_membership_factory do
    %Plausible.Site.Membership{}
  end

  def ch_session_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")

    %Plausible.ClickhouseSession{
      sign: 1,
      session_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      user_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      hostname: hostname,
      domain: hostname,
      referrer: "",
      referrer_source: "",
      utm_medium: "",
      utm_source: "",
      utm_campaign: "",
      utm_content: "",
      utm_term: "",
      entry_page: "/",
      pageviews: 1,
      events: 1,
      duration: 0,
      start: Timex.now(),
      timestamp: Timex.now(),
      is_bounce: false,
      browser: "",
      browser_version: "",
      country_code: "",
      screen_size: "",
      operating_system: "",
      operating_system_version: ""
    }
  end

  def pageview_factory do
    struct!(
      event_factory(),
      %{
        name: "pageview"
      }
    )
  end

  def event_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")

    %Plausible.ClickhouseEvent{
      hostname: hostname,
      domain: hostname,
      pathname: "/",
      timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      event_id: Plausible.ClickhouseEvent.random_event_id(),
      user_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      session_id: SipHash.hash!(hash_key(), UUID.uuid4()),
      referrer: "",
      referrer_source: "",
      utm_medium: "",
      utm_source: "",
      utm_campaign: "",
      utm_content: "",
      utm_term: "",
      browser: "",
      browser_version: "",
      country_code: "",
      screen_size: "",
      operating_system: "",
      operating_system_version: "",
      "meta.key": [],
      "meta.value": []
    }
  end

  defp hash_key() do
    Keyword.fetch!(
      Application.get_env(:plausible, PlausibleWeb.Endpoint),
      :secret_key_base
    )
    |> binary_part(0, 16)
  end
end
