defmodule Plausible.Tracking.Actions.EventTest do
  use ExUnit.Case, async: true

  alias Plausible.Tracking.Actions.Event

  describe "extract_core_params/1" do
    test "extracts full parameter names" do
      params = %{
        "name" => "pageview",
        "url" => "https://example.com/page",
        "referrer" => "https://google.com",
        "domain" => "example.com",
        "screen_width" => 1920,
        "hashMode" => true
      }

      result = Event.extract_core_params(params)

      assert result == %{
        "name" => "pageview",
        "url" => "https://example.com/page",
        "referrer" => "https://google.com",
        "domain" => "example.com",
        "screen_width" => 1920,
        "hash_mode" => true
      }
    end

    test "extracts shorthand parameter names" do
      params = %{
        "n" => "pageview",
        "u" => "https://example.com/page",
        "r" => "https://google.com",
        "d" => "example.com",
        "w" => 1920,
        "h" => true
      }

      result = Event.extract_core_params(params)

      assert result == %{
        "name" => "pageview",
        "url" => "https://example.com/page",
        "referrer" => "https://google.com",
        "domain" => "example.com",
        "screen_width" => 1920,
        "hash_mode" => true
      }
    end

    test "shorthand takes precedence over full names" do
      params = %{
        "name" => "full_name",
        "n" => "shorthand_name"
      }

      result = Event.extract_core_params(params)

      assert result["name"] == "shorthand_name"
    end

    test "handles missing parameters gracefully" do
      params = %{}

      result = Event.extract_core_params(params)

      assert result == %{
        "name" => nil,
        "url" => nil,
        "referrer" => nil,
        "domain" => nil,
        "screen_width" => nil,
        "hash_mode" => nil
      }
    end
  end

  describe "is_bot?/1" do
    test "returns true for UAInspector.Result.Bot" do
      bot_result = %UAInspector.Result.Bot{
        name: "Googlebot",
        category: "Search bot"
      }

      assert Event.is_bot?(bot_result)
    end

    test "returns false for regular user agent" do
      ua_result = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Chrome", type: "browser"},
        os: %UAInspector.Result.OS{name: "Mac"}
      }

      refute Event.is_bot?(ua_result)
    end

    test "returns false for nil" do
      refute Event.is_bot?(nil)
    end

    test "returns true for Headless Chrome in production" do
      initial_env = Application.get_env(:plausible, :system_environment)
      Application.put_env(:plausible, :system_environment, "production")

      ua_result = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Headless Chrome", type: "browser"},
        os: %UAInspector.Result.OS{name: "Linux"}
      }

      assert Event.is_bot?(ua_result)

      Application.put_env(:plausible, :system_environment, initial_env)
    end

    test "returns false for Headless Chrome in staging" do
      initial_env = Application.get_env(:plausible, :system_environment)
      Application.put_env(:plausible, :system_environment, "staging")

      ua_result = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Headless Chrome", type: "browser"},
        os: %UAInspector.Result.OS{name: "Linux"}
      }

      refute Event.is_bot?(ua_result)

      Application.put_env(:plausible, :system_environment, initial_env)
    end

    test "returns false for Headless Chrome in rc" do
      initial_env = Application.get_env(:plausible, :system_environment)
      Application.put_env(:plausible, :system_environment, "rc")

      ua_result = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Headless Chrome", type: "browser"},
        os: %UAInspector.Result.OS{name: "Linux"}
      }

      refute Event.is_bot?(ua_result)

      Application.put_env(:plausible, :system_environment, initial_env)
    end
  end

  describe "is_spammer?/1" do
    test "returns false for nil referrer" do
      refute Event.is_spammer?(nil)
    end

    test "returns false for legitimate referrers" do
      refute Event.is_spammer?("https://google.com")
      refute Event.is_spammer?("https://facebook.com/page")
    end

    test "returns true for known spam referrers" do
      assert Event.is_spammer?("https://www.1-best-seo.com")
    end
  end

  describe "parse_meta/1" do
    test "parses meta from 'meta' key" do
      params = %{"meta" => %{"key1" => "value1", "key2" => "value2"}}

      result = Event.parse_meta(params)

      assert result == %{"key1" => "value1", "key2" => "value2"}
    end

    test "parses meta from 'm' key (shorthand)" do
      params = %{"m" => %{"key1" => "value1"}}

      result = Event.parse_meta(params)

      assert result == %{"key1" => "value1"}
    end

    test "parses meta from 'props' key" do
      params = %{"props" => %{"key1" => "value1"}}

      result = Event.parse_meta(params)

      assert result == %{"key1" => "value1"}
    end

    test "parses meta from 'p' key (shorthand)" do
      params = %{"p" => %{"key1" => "value1"}}

      result = Event.parse_meta(params)

      assert result == %{"key1" => "value1"}
    end

    test "parses JSON-encoded meta" do
      params = %{"meta" => ~s({"key1": "value1", "key2": 123})}

      result = Event.parse_meta(params)

      assert result == %{"key1" => "value1", "key2" => 123}
    end

    test "returns empty map for invalid JSON" do
      params = %{"meta" => "invalid json"}

      result = Event.parse_meta(params)

      assert result == %{}
    end

    test "returns empty map for array values in meta" do
      params = %{"meta" => %{"key1" => ["array", "value"]}}

      result = Event.parse_meta(params)

      assert result == %{}
    end

    test "returns empty map for nested map values in meta" do
      params = %{"meta" => %{"key1" => %{"nested" => "value"}}}

      result = Event.parse_meta(params)

      assert result == %{}
    end

    test "returns empty map when no meta keys present" do
      params = %{"other" => "value"}

      result = Event.parse_meta(params)

      assert result == %{}
    end
  end

  describe "validate_custom_props/1" do
    test "returns :ok for valid props with string values" do
      props = %{"key1" => "value1", "key2" => "value2"}

      assert Event.validate_custom_props(props) == :ok
    end

    test "returns :ok for props with numeric values" do
      props = %{"key1" => 123, "key2" => 45.67}

      assert Event.validate_custom_props(props) == :ok
    end

    test "returns :ok for props with boolean values" do
      props = %{"key1" => true, "key2" => false}

      assert Event.validate_custom_props(props) == :ok
    end

    test "returns :invalid_props for props with array values" do
      props = %{"key1" => ["value1", "value2"]}

      assert Event.validate_custom_props(props) == :invalid_props
    end

    test "returns :invalid_props for props with map values" do
      props = %{"key1" => %{"nested" => "value"}}

      assert Event.validate_custom_props(props) == :invalid_props
    end

    test "returns :ok for empty props" do
      props = %{}

      assert Event.validate_custom_props(props) == :ok
    end
  end

  describe "decode_raw_props/1" do
    test "returns {:ok, map} for map input" do
      props = %{"key1" => "value1"}

      assert Event.decode_raw_props(props) == {:ok, props}
    end

    test "returns {:ok, map} for valid JSON string" do
      json = ~s({"key1": "value1", "key2": 123})

      assert Event.decode_raw_props(json) == {:ok, %{"key1" => "value1", "key2" => 123}}
    end

    test "returns :not_a_map for JSON array" do
      json = ~s(["value1", "value2"])

      assert Event.decode_raw_props(json) == :not_a_map
    end

    test "returns :not_a_map for invalid JSON" do
      json = "not valid json"

      assert Event.decode_raw_props(json) == :not_a_map
    end

    test "returns :bad_format for nil" do
      assert Event.decode_raw_props(nil) == :bad_format
    end

    test "returns :bad_format for numbers" do
      assert Event.decode_raw_props(123) == :bad_format
    end

    test "returns :bad_format for atoms" do
      assert Event.decode_raw_props(:some_atom) == :bad_format
    end
  end

  describe "parse_additional_params/1" do
    test "extracts special params from meta and separates them" do
      params = %{
        "meta" => %{
          "campaign_id" => "camp-123",
          "company_id" => 456,
          "job_id" => 789,
          "custom_key" => "custom_value"
        }
      }

      result = Event.parse_additional_params(params)

      assert result["campaign_id"] == "camp-123"
      assert result["company_id"] == 456
      assert result["job_id"] == 789
      assert result["meta"]["custom_key"] == "custom_value"
      refute Map.has_key?(result["meta"], "campaign_id")
    end

    test "handles all special param names" do
      special_params = [
        "campaign_id",
        "careers_application_form_uuid",
        "company_id",
        "job_id",
        "page_id",
        "product_id",
        "site_id"
      ]

      meta = Enum.into(special_params, %{}, fn name -> {name, "value_#{name}"} end)
      params = %{"meta" => meta}

      result = Event.parse_additional_params(params)

      Enum.each(special_params, fn name ->
        assert result[name] == "value_#{name}"
      end)

      assert result["meta"] == %{}
    end
  end

  describe "get_domains/2" do
    test "splits comma-separated domains" do
      params = %{"domain" => "example1.com, example2.com, example3.com"}
      uri = nil

      result = Event.get_domains(params, uri)

      assert result == ["example1.com", "example2.com", "example3.com"]
    end

    test "strips www from domains" do
      params = %{"domain" => "www.example.com"}
      uri = nil

      result = Event.get_domains(params, uri)

      assert result == ["example.com"]
    end

    test "extracts domain from URI host when not specified" do
      params = %{}
      uri = URI.parse("https://www.example.com/page")

      result = Event.get_domains(params, uri)

      assert result == ["example.com"]
    end

    test "returns empty list for nil params and nil uri" do
      params = %{}
      uri = nil

      result = Event.get_domains(params, uri)

      assert result == []
    end
  end

  describe "get_pathname/2" do
    test "returns / for nil URI" do
      assert Event.get_pathname(nil, false) == "/"
    end

    test "returns path from URI" do
      uri = URI.parse("https://example.com/some/path")

      assert Event.get_pathname(uri, false) == "/some/path"
    end

    test "returns / when path is nil" do
      uri = URI.parse("https://example.com")

      assert Event.get_pathname(uri, false) == "/"
    end

    test "includes fragment in hash mode" do
      uri = URI.parse("https://example.com/page#section")

      assert Event.get_pathname(uri, true) == "/page#section"
    end

    test "does not include fragment when not in hash mode" do
      uri = URI.parse("https://example.com/page#section")

      assert Event.get_pathname(uri, false) == "/page"
    end

    test "decodes URL-encoded paths" do
      uri = URI.parse("https://example.com/%D8%B5%D9%81%D8%AD%D9%87")

      assert Event.get_pathname(uri, false) == "/صفحه"
    end
  end

  describe "get_location_details/1" do
    test "returns empty values for nil geo_data" do
      result = Event.get_location_details(nil)

      assert result.country_code == ""
      assert result.subdivision1_code == ""
      assert result.subdivision2_code == ""
      assert result.city_geoname_id == ""
    end

    test "extracts country code" do
      geo_data = %{"country" => %{"iso_code" => "US"}}

      result = Event.get_location_details(geo_data)

      assert result.country_code == "US"
    end

    test "extracts subdivision codes" do
      geo_data = %{
        "country" => %{"iso_code" => "US"},
        "subdivisions" => [
          %{"iso_code" => "CA"},
          %{"iso_code" => "SF"}
        ]
      }

      result = Event.get_location_details(geo_data)

      assert result.subdivision1_code == "US-CA"
      assert result.subdivision2_code == "US-SF"
    end

    test "extracts city geoname_id" do
      geo_data = %{
        "city" => %{"geoname_id" => 5_391_959}
      }

      result = Event.get_location_details(geo_data)

      assert result.city_geoname_id == 5_391_959
    end
  end

  describe "get_country_code/1" do
    test "returns empty string for nil" do
      assert Event.get_country_code(nil) == ""
    end

    test "returns country iso_code" do
      geo_data = %{"country" => %{"iso_code" => "GB"}}

      assert Event.get_country_code(geo_data) == "GB"
    end

    test "ignores ZZ country code" do
      geo_data = %{"country" => %{"iso_code" => "ZZ"}}

      assert Event.get_country_code(geo_data) == ""
    end

    test "returns empty string when country is missing" do
      geo_data = %{}

      assert Event.get_country_code(geo_data) == ""
    end
  end

  describe "get_subdivision_code/2" do
    test "returns empty string for nil geo_data" do
      assert Event.get_subdivision_code(nil, 0) == ""
    end

    test "returns subdivision code with country prefix" do
      geo_data = %{
        "country" => %{"iso_code" => "US"},
        "subdivisions" => [%{"iso_code" => "NY"}]
      }

      assert Event.get_subdivision_code(geo_data, 0) == "US-NY"
    end

    test "returns empty string when subdivision index not found" do
      geo_data = %{
        "country" => %{"iso_code" => "US"},
        "subdivisions" => []
      }

      assert Event.get_subdivision_code(geo_data, 0) == ""
    end
  end

  describe "ignore_unknown_country/1" do
    test "returns empty string for ZZ" do
      assert Event.ignore_unknown_country("ZZ") == ""
    end

    test "returns empty string for nil" do
      assert Event.ignore_unknown_country(nil) == ""
    end

    test "returns the country code for valid codes" do
      assert Event.ignore_unknown_country("US") == "US"
      assert Event.ignore_unknown_country("GB") == "GB"
    end
  end

  describe "calculate_screen_size/1" do
    test "returns nil for nil width" do
      assert Event.calculate_screen_size(nil) == nil
    end

    test "returns Mobile for width < 576" do
      assert Event.calculate_screen_size(320) == "Mobile"
      assert Event.calculate_screen_size(575) == "Mobile"
    end

    test "returns Tablet for width >= 576 and < 992" do
      assert Event.calculate_screen_size(576) == "Tablet"
      assert Event.calculate_screen_size(768) == "Tablet"
      assert Event.calculate_screen_size(991) == "Tablet"
    end

    test "returns Laptop for width >= 992 and < 1440" do
      assert Event.calculate_screen_size(992) == "Laptop"
      assert Event.calculate_screen_size(1280) == "Laptop"
      assert Event.calculate_screen_size(1439) == "Laptop"
    end

    test "returns Desktop for width >= 1440" do
      assert Event.calculate_screen_size(1440) == "Desktop"
      assert Event.calculate_screen_size(1920) == "Desktop"
      assert Event.calculate_screen_size(2560) == "Desktop"
    end
  end

  describe "strip_www/1" do
    test "returns nil for nil input" do
      assert Event.strip_www(nil) == nil
    end

    test "strips www. prefix" do
      assert Event.strip_www("www.example.com") == "example.com"
    end

    test "does not modify hostnames without www." do
      assert Event.strip_www("example.com") == "example.com"
    end

    test "only strips leading www." do
      assert Event.strip_www("www.www.example.com") == "www.example.com"
    end
  end

  describe "browser_name/1" do
    test "returns empty string for nil" do
      assert Event.browser_name(nil) == ""
    end

    test "returns empty string for unknown client" do
      ua = %UAInspector.Result{client: :unknown}

      assert Event.browser_name(ua) == ""
    end

    test "normalizes Mobile Safari to Safari" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Mobile Safari", type: "browser"}
      }

      assert Event.browser_name(ua) == "Safari"
    end

    test "normalizes Chrome Mobile to Chrome" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Chrome Mobile", type: "browser"}
      }

      assert Event.browser_name(ua) == "Chrome"
    end

    test "normalizes Chrome Mobile iOS to Chrome" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Chrome Mobile iOS", type: "browser"}
      }

      assert Event.browser_name(ua) == "Chrome"
    end

    test "normalizes Firefox Mobile to Firefox" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Firefox Mobile", type: "browser"}
      }

      assert Event.browser_name(ua) == "Firefox"
    end

    test "normalizes Firefox Mobile iOS to Firefox" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Firefox Mobile iOS", type: "browser"}
      }

      assert Event.browser_name(ua) == "Firefox"
    end

    test "normalizes Opera Mobile to Opera" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Opera Mobile", type: "browser"}
      }

      assert Event.browser_name(ua) == "Opera"
    end

    test "normalizes Opera Mini to Opera" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Opera Mini", type: "browser"}
      }

      assert Event.browser_name(ua) == "Opera"
    end

    test "normalizes Opera Mini iOS to Opera" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Opera Mini iOS", type: "browser"}
      }

      assert Event.browser_name(ua) == "Opera"
    end

    test "normalizes Yandex Browser Lite to Yandex Browser" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Yandex Browser Lite", type: "browser"}
      }

      assert Event.browser_name(ua) == "Yandex Browser"
    end

    test "normalizes Chrome Webview to Mobile App" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Chrome Webview", type: "browser"}
      }

      assert Event.browser_name(ua) == "Mobile App"
    end

    test "normalizes mobile app type to Mobile App" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "SomeApp", type: "mobile app"}
      }

      assert Event.browser_name(ua) == "Mobile App"
    end

    test "returns original name for regular browsers" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "Chrome", type: "browser"}
      }

      assert Event.browser_name(ua) == "Chrome"
    end
  end

  describe "browser_version/1" do
    test "returns empty string for nil" do
      assert Event.browser_version(nil) == ""
    end

    test "returns empty string for unknown client" do
      ua = %UAInspector.Result{client: :unknown}

      assert Event.browser_version(ua) == ""
    end

    test "returns empty string for mobile apps" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{name: "SomeApp", type: "mobile app", version: "1.2.3"}
      }

      assert Event.browser_version(ua) == ""
    end

    test "returns major.minor version" do
      ua = %UAInspector.Result{
        client: %UAInspector.Result.Client{
          name: "Chrome",
          type: "browser",
          version: "91.0.4472.77"
        }
      }

      assert Event.browser_version(ua) == "91.0"
    end
  end

  describe "os_name/1" do
    test "returns empty string for nil" do
      assert Event.os_name(nil) == ""
    end

    test "returns empty string for unknown OS" do
      ua = %UAInspector.Result{os: :unknown}

      assert Event.os_name(ua) == ""
    end

    test "returns OS name" do
      ua = %UAInspector.Result{
        os: %UAInspector.Result.OS{name: "Windows"}
      }

      assert Event.os_name(ua) == "Windows"
    end
  end

  describe "os_version/1" do
    test "returns empty string for nil" do
      assert Event.os_version(nil) == ""
    end

    test "returns empty string for unknown OS" do
      ua = %UAInspector.Result{os: :unknown}

      assert Event.os_version(ua) == ""
    end

    test "returns major.minor version" do
      ua = %UAInspector.Result{
        os: %UAInspector.Result.OS{name: "Windows", version: "10.0.19041"}
      }

      assert Event.os_version(ua) == "10.0"
    end
  end

  describe "major_minor/1" do
    test "returns empty string for :unknown" do
      assert Event.major_minor(:unknown) == ""
    end

    test "returns full version when only major" do
      assert Event.major_minor("10") == "10"
    end

    test "returns major.minor when three parts" do
      assert Event.major_minor("10.0.19041") == "10.0"
    end

    test "returns major.minor when four parts" do
      assert Event.major_minor("91.0.4472.77") == "91.0"
    end
  end

  describe "get_referrer_source/2" do
    test "returns source from query params when present" do
      query = %{"source" => "newsletter"}

      assert Event.get_referrer_source(query, nil) == "newsletter"
    end

    test "returns utm_source from query params when present" do
      query = %{"utm_source" => "twitter"}

      assert Event.get_referrer_source(query, nil) == "twitter"
    end

    test "prefers source over utm_source" do
      query = %{"source" => "newsletter", "utm_source" => "twitter"}

      assert Event.get_referrer_source(query, nil) == "newsletter"
    end

    test "returns nil for nil query" do
      assert Event.get_referrer_source(nil, nil) == nil
    end
  end

  describe "decode_query_params/1" do
    test "returns nil for nil URI" do
      assert Event.decode_query_params(nil) == nil
    end

    test "returns nil for URI without query" do
      uri = URI.parse("https://example.com/page")

      assert Event.decode_query_params(uri) == nil
    end

    test "decodes query parameters" do
      uri = URI.parse("https://example.com/page?foo=bar&baz=qux")

      assert Event.decode_query_params(uri) == %{"foo" => "bar", "baz" => "qux"}
    end

    test "decodes URL-encoded values" do
      uri = URI.parse("https://example.com?name=John%20Doe&city=New%20York")

      assert Event.decode_query_params(uri) == %{"name" => "John Doe", "city" => "New York"}
    end
  end

  describe "clean_referrer/1" do
    test "returns nil for nil referrer" do
      assert Event.clean_referrer(nil) == nil
    end
  end

  describe "get_root_domain/1" do
    test "returns (none) for nil" do
      assert Event.get_root_domain(nil) == "(none)"
    end

    test "extracts registrable domain" do
      assert Event.get_root_domain("www.example.com") == "example.com"
      assert Event.get_root_domain("blog.example.com") == "example.com"
      assert Event.get_root_domain("sub.blog.example.com") == "example.com"
    end

    test "returns hostname when no registrable domain" do
      assert Event.get_root_domain("localhost") == "localhost"
    end
  end
end
