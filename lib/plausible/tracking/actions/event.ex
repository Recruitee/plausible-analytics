defmodule Plausible.Tracking.Actions.Event do
  @moduledoc """
  Handles the creation of analytics events from external tracking requests.

  This module processes incoming event data, performs validation, bot detection,
  spam filtering, geolocation lookups, and persists events to the database.
  """

  @no_domain_error {:error, %{domain: ["can't be blank"]}}

  # City geoname ID overrides for specific locations
  @city_overrides %{}

  @doc """
  Creates an event from the given connection and parameters.

  Returns `:ok` on success or `{:error, errors}` on failure.

  ## Parameters

    * `conn` - The Plug connection containing request metadata
    * `params` - A map containing event parameters

  ## Event Parameters

  The following parameters are supported (with shorthand aliases):

    * `name` (or `n`) - Event name (e.g., "pageview", "custom event")
    * `url` (or `u`) - The page URL
    * `referrer` (or `r`) - The referrer URL
    * `domain` (or `d`) - The site domain(s), comma-separated for multiple
    * `screen_width` (or `w`) - Screen width in pixels
    * `hash_mode` (or `h`) - Enable hash-based routing mode

  ## Examples

      iex> Plausible.Tracking.Actions.Event.create(conn, %{"name" => "pageview", "url" => "https://example.com", "domain" => "example.com"})
      :ok

      iex> Plausible.Tracking.Actions.Event.create(conn, %{"n" => "pageview", "u" => "https://example.com", "d" => "example.com"})
      :ok
  """
  @spec create(Plug.Conn.t(), map()) :: :ok | {:error, map()}
  def create(conn, params) do
    core_params = extract_core_params(params)
    additional_params = parse_additional_params(params)
    params = Map.merge(core_params, additional_params)

    ua = parse_user_agent(conn)

    cond do
      is_bot?(ua) -> :ok
      blacklisted_domain?(params["domain"]) -> :ok
      is_spammer?(params["referrer"]) -> :ok
      true -> process_event(conn, params, ua)
    end
  end

  @spec extract_core_params(map()) :: map()
  def extract_core_params(params) do
    %{
      "name" => params["n"] || params["name"],
      "url" => params["u"] || params["url"],
      "referrer" => params["r"] || params["referrer"],
      "domain" => params["d"] || params["domain"],
      "screen_width" => params["w"] || params["screen_width"],
      "hash_mode" => params["h"] || params["hashMode"]
    }
  end

  @spec parse_additional_params(map()) :: map()
  def parse_additional_params(params) do
    additional_param_names = [
      "campaign_id",
      "careers_application_form_uuid",
      "company_id",
      "job_id",
      "page_id",
      "product_id",
      "site_id"
    ]

    meta = parse_meta(params)

    meta
    |> Map.take(additional_param_names)
    |> Map.merge(%{"meta" => Map.drop(meta, additional_param_names)})
  end

  @spec parse_user_agent(Plug.Conn.t()) :: UAInspector.Result.t() | nil
  def parse_user_agent(conn) do
    user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first()

    if user_agent do
      res =
        Cachex.fetch(:user_agents, user_agent, fn ua ->
          UAInspector.parse(ua)
        end)

      case res do
        {:ok, user_agent} -> user_agent
        {:commit, user_agent} -> user_agent
        _ -> nil
      end
    end
  end

  @spec is_bot?(UAInspector.Result.t() | nil) :: boolean()
  def is_bot?(%UAInspector.Result.Bot{}), do: true

  def is_bot?(%UAInspector.Result{client: %UAInspector.Result.Client{name: "Headless Chrome"}}) do
    Application.get_env(:plausible, :system_environment) not in ["rc", "staging"]
  end

  def is_bot?(_), do: false

  @spec blacklisted_domain?(String.t() | nil) :: boolean()
  def blacklisted_domain?(domain) do
    domain in []
  end

  @spec is_spammer?(String.t() | nil) :: boolean()
  def is_spammer?(nil), do: false

  def is_spammer?(referrer_str) do
    uri = URI.parse(referrer_str)
    ReferrerBlocklist.is_spammer?(strip_www(uri.host))
  end

  @spec parse_meta(map()) :: map()
  def parse_meta(params) do
    raw_meta = params["m"] || params["meta"] || params["p"] || params["props"]

    with {:ok, parsed_json} <- decode_raw_props(raw_meta),
         :ok <- validate_custom_props(parsed_json) do
      parsed_json
    else
      _ -> %{}
    end
  end

  @spec validate_custom_props(map()) :: :ok | :invalid_props
  def validate_custom_props(props) do
    is_valid =
      Enum.all?(props, fn {_key, val} ->
        !is_list(val) && !is_map(val)
      end)

    if is_valid, do: :ok, else: :invalid_props
  end

  @spec decode_raw_props(map() | String.t() | any()) :: {:ok, map()} | :not_a_map | :bad_format
  def decode_raw_props(props) when is_map(props), do: {:ok, props}

  def decode_raw_props(raw_json) when is_binary(raw_json) do
    case Jason.decode(raw_json) do
      {:ok, parsed_props} when is_map(parsed_props) ->
        {:ok, parsed_props}

      _ ->
        :not_a_map
    end
  end

  def decode_raw_props(_), do: :bad_format

  @spec get_domains(map(), URI.t() | nil) :: [String.t()]
  def get_domains(params, uri) do
    if params["domain"] do
      String.split(params["domain"], ",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&strip_www/1)
    else
      List.wrap(strip_www(uri && uri.host))
    end
  end

  @spec get_pathname(URI.t() | nil, any()) :: String.t()
  def get_pathname(nil, _), do: "/"

  def get_pathname(uri, hash_mode) do
    pathname =
      (uri.path || "/")
      |> URI.decode()

    if hash_mode && uri.fragment do
      pathname <> "#" <> URI.decode(uri.fragment)
    else
      pathname
    end
  end

  @spec visitor_location_details(Plug.Conn.t()) :: map()
  def visitor_location_details(conn) do
    ip = PlausibleWeb.RemoteIp.get(conn)
    result = Plausible.Geolocation.lookup(ip)

    case result do
      {:ok, result} ->
        get_location_details(result)

      _ ->
        get_location_details(nil)
    end
  end

  @spec get_location_details(map() | nil) :: map()
  def get_location_details(geo_data) do
    %{
      country_code: get_country_code(geo_data),
      country_geoname_id: get_country_geoname_id(geo_data),
      subdivision1_code: get_subdivision_code(geo_data, 0),
      subdivision2_code: get_subdivision_code(geo_data, 1),
      city_geoname_id: get_city_geoname_id(geo_data)
    }
  end

  @spec get_country_code(map() | nil) :: String.t()
  def get_country_code(nil), do: ""

  def get_country_code(geo_data) do
    geo_data
    |> Map.get("country", %{})
    |> Map.get("iso_code")
    |> ignore_unknown_country()
  end

  @spec get_country_geoname_id(map() | nil) :: String.t() | integer()
  def get_country_geoname_id(nil), do: ""

  def get_country_geoname_id(geo_data) do
    geo_data
    |> Map.get("country", %{})
    |> Map.get("geoname_id", "")
  end

  @spec get_city_geoname_id(map() | nil) :: String.t() | integer()
  def get_city_geoname_id(nil), do: ""

  def get_city_geoname_id(geo_data) do
    city =
      geo_data
      |> Map.get("city", %{})
      |> Map.get("geoname_id", "")

    Map.get(@city_overrides, city, city)
  end

  @spec get_subdivision_code(map() | nil, non_neg_integer()) :: String.t()
  def get_subdivision_code(nil, _), do: ""

  def get_subdivision_code(geo_data, n) do
    subdivisions = Map.get(geo_data, "subdivisions", [])
    country_code = get_country_code(geo_data)

    case Enum.at(subdivisions, n) do
      %{"iso_code" => iso_code} -> country_code <> "-" <> iso_code
      _ -> ""
    end
  end

  @spec ignore_unknown_country(String.t() | nil) :: String.t()
  def ignore_unknown_country("ZZ"), do: ""
  def ignore_unknown_country(nil), do: ""
  def ignore_unknown_country(country), do: country

  @spec parse_referrer(URI.t() | nil, String.t() | nil) :: RefInspector.Result.t() | nil
  def parse_referrer(_, nil), do: nil

  def parse_referrer(uri, referrer_str) do
    referrer_uri = URI.parse(referrer_str)

    if strip_www(referrer_uri.host) !== strip_www(uri.host) && referrer_uri.host !== "localhost" do
      RefInspector.parse(referrer_str)
    end
  end

  @spec generate_user_id(Plug.Conn.t(), String.t() | nil, String.t() | nil, String.t() | nil) ::
          integer() | nil
  def generate_user_id(conn, domain, hostname, salt) do
    user_agent = List.first(Plug.Conn.get_req_header(conn, "user-agent")) || ""
    ip_address = PlausibleWeb.RemoteIp.get(conn)
    root_domain = get_root_domain(hostname)

    if domain && root_domain do
      SipHash.hash!(salt, user_agent <> ip_address <> domain <> root_domain)
    end
  end

  @spec get_root_domain(String.t() | nil) :: String.t()
  def get_root_domain(nil), do: "(none)"

  def get_root_domain(hostname) do
    case PublicSuffix.registrable_domain(hostname) do
      domain when is_binary(domain) -> domain
      _ -> hostname
    end
  end

  @spec calculate_screen_size(integer() | nil) :: String.t() | nil
  def calculate_screen_size(nil), do: nil
  def calculate_screen_size(width) when width < 576, do: "Mobile"
  def calculate_screen_size(width) when width < 992, do: "Tablet"
  def calculate_screen_size(width) when width < 1440, do: "Laptop"
  def calculate_screen_size(width) when width >= 1440, do: "Desktop"

  @spec clean_referrer(RefInspector.Result.t() | nil) :: String.t() | nil
  def clean_referrer(nil), do: nil

  def clean_referrer(ref) do
    uri = URI.parse(ref.referer)

    if PlausibleWeb.RefInspector.right_uri?(uri) do
      host = String.replace_prefix(uri.host, "www.", "")
      path = uri.path || ""
      host <> String.trim_trailing(path, "/")
    end
  end

  @spec strip_www(String.t() | nil) :: String.t() | nil
  def strip_www(nil), do: nil

  def strip_www(hostname) do
    String.replace_prefix(hostname, "www.", "")
  end

  @spec browser_name(UAInspector.Result.t() | nil) :: String.t()
  def browser_name(nil), do: ""

  def browser_name(ua) do
    case ua.client do
      :unknown -> ""
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{name: "Firefox Mobile"} -> "Firefox"
      %UAInspector.Result.Client{name: "Firefox Mobile iOS"} -> "Firefox"
      %UAInspector.Result.Client{name: "Opera Mobile"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini iOS"} -> "Opera"
      %UAInspector.Result.Client{name: "Yandex Browser Lite"} -> "Yandex Browser"
      %UAInspector.Result.Client{name: "Chrome Webview"} -> "Mobile App"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      client -> client.name
    end
  end

  @spec browser_version(UAInspector.Result.t() | nil) :: String.t()
  def browser_version(nil), do: ""

  def browser_version(ua) do
    case ua.client do
      :unknown -> ""
      %UAInspector.Result.Client{type: "mobile app"} -> ""
      client -> major_minor(client.version)
    end
  end

  @spec os_name(UAInspector.Result.t() | nil) :: String.t()
  def os_name(nil), do: ""

  def os_name(ua) do
    case ua.os do
      :unknown -> ""
      os -> os.name
    end
  end

  @spec os_version(UAInspector.Result.t() | nil) :: String.t()
  def os_version(nil), do: ""

  def os_version(ua) do
    case ua.os do
      :unknown -> ""
      os -> major_minor(os.version)
    end
  end

  @spec major_minor(String.t() | :unknown) :: String.t()
  def major_minor(:unknown), do: ""

  def major_minor(version) do
    version
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end

  @spec get_referrer_source(map() | nil, RefInspector.Result.t() | nil) :: String.t() | nil
  def get_referrer_source(query, ref) do
    source = query["source"] || query["utm_source"]
    source || PlausibleWeb.RefInspector.parse(ref)
  end

  @spec decode_query_params(URI.t() | nil) :: map() | nil
  def decode_query_params(nil), do: nil
  def decode_query_params(%URI{query: nil}), do: nil

  def decode_query_params(%URI{query: query_part}) do
    try do
      URI.decode_query(query_part)
    rescue
      _ -> nil
    end
  end

  defp process_event(conn, params, ua) do
    uri = params["url"] && URI.parse(params["url"])
    host = if uri && uri.host == "", do: "(none)", else: uri && uri.host
    query = decode_query_params(uri)

    ref = parse_referrer(uri, params["referrer"])
    location_details = visitor_location_details(conn)
    salts = Plausible.Session.Salts.fetch()

    event_attrs = build_event_attrs(params, ua, uri, host, query, ref, location_details)

    Enum.reduce_while(get_domains(params, uri), @no_domain_error, fn domain, _res ->
      user_id = generate_user_id(conn, domain, event_attrs[:hostname], salts[:current])

      previous_user_id =
        salts[:previous] &&
          generate_user_id(conn, domain, event_attrs[:hostname], salts[:previous])

      changeset =
        event_attrs
        |> Map.merge(%{domain: domain, user_id: user_id})
        |> Plausible.Event.new()

      if changeset.valid? do
        event = Ecto.Changeset.apply_changes(changeset)
        session_id = Plausible.Session.Store.on_event(event, previous_user_id)

        event
        |> Map.put(:session_id, session_id)
        |> Plausible.Event.WriteBuffer.insert()

        {:cont, :ok}
      else
        errors = Ecto.Changeset.traverse_errors(changeset, &encode_error/1)
        {:halt, {:error, errors}}
      end
    end)
  end

  defp build_event_attrs(params, ua, uri, host, query, ref, location_details) do
    %{
      event_id: Plausible.Event.random_event_id(),
      timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      name: params["name"],
      hostname: strip_www(host),
      pathname: get_pathname(uri, params["hash_mode"]),
      referrer_source: get_referrer_source(query, ref),
      referrer: clean_referrer(ref),
      utm_medium: query["utm_medium"],
      utm_source: query["utm_source"],
      utm_campaign: query["utm_campaign"],
      utm_content: query["utm_content"],
      utm_term: query["utm_term"],
      company_id: params["company_id"],
      job_id: params["job_id"],
      page_id: params["page_id"],
      site_id: params["site_id"],
      campaign_id: params["campaign_id"],
      product_id: params["product_id"],
      country_code: location_details[:country_code],
      country_geoname_id: location_details[:country_geoname_id],
      subdivision1_code: location_details[:subdivision1_code],
      subdivision2_code: location_details[:subdivision2_code],
      city_geoname_id: location_details[:city_geoname_id],
      operating_system: os_name(ua),
      operating_system_version: os_version(ua),
      browser: browser_name(ua),
      browser_version: browser_version(ua),
      screen_size: calculate_screen_size(params["screen_width"]),
      careers_application_form_uuid: params["careers_application_form_uuid"],
      "meta.key": Map.keys(params["meta"] || %{}),
      "meta.value": Map.values(params["meta"] || %{}) |> Enum.map(&Kernel.to_string/1)
    }
  end

  defp encode_error({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
