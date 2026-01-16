defmodule PlausibleWeb.Api.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  use Plug.ErrorHandler
  alias Plausible.Stats
  alias Plausible.Stats.{Query, Filters}

  @timezone "Europe/Warsaw"

  def main_graph(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    timeseries_query =
      if query.period == "realtime" do
        %Query{query | period: "30m"}
      else
        query
      end

    timeseries = Task.async(fn -> Stats.timeseries(site, timeseries_query, [:visitors]) end)
    {top_stats, sample_percent} = fetch_top_stats(site, query)

    timeseries_result = Task.await(timeseries)
    plot = Enum.map(timeseries_result, fn row -> row[:visitors] end)
    labels = Enum.map(timeseries_result, fn row -> row[:date] end)
    present_index = present_index_for(site, query, labels)

    json(conn, %{
      plot: plot,
      labels: labels,
      present_index: present_index,
      top_stats: top_stats,
      interval: query.interval,
      sample_percent: sample_percent
    })
  end

  defp present_index_for(_site, query, dates) do
    case query.interval do
      "hour" ->
        current_date =
          Timex.now(@timezone)
          |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:00:00")

        Enum.find_index(dates, &(&1 == current_date))

      "date" ->
        current_date =
          Timex.now(@timezone)
          |> Timex.to_date()

        Enum.find_index(dates, &(&1 == current_date))

      "month" ->
        current_date =
          Timex.now(@timezone)
          |> Timex.to_date()
          |> Timex.beginning_of_month()

        Enum.find_index(dates, &(&1 == current_date))

      "minute" ->
        nil
    end
  end

  defp fetch_top_stats(site, %Query{period: "realtime"} = query) do
    query_30m = %Query{query | period: "30m"}

    %{
      visitors: %{value: visitors},
      pageviews: %{value: pageviews}
    } = Stats.aggregate(site, query_30m, [:visitors, :pageviews])

    stats = [
      %{
        name: "Current visitors",
        value: Stats.current_visitors(site)
      },
      %{
        name: "Unique visitors (last 30 min)",
        value: visitors
      },
      %{
        name: "Pageviews (last 30 min)",
        value: pageviews
      }
    ]

    {stats, 100}
  end

  defp fetch_top_stats(site, query) do
    prev_query = Query.shift_back(query, site)

    metrics =
      if query.filters["event:page"] do
        [:visitors, :pageviews, :bounce_rate, :time_on_page, :sample_percent]
      else
        [:visitors, :pageviews, :bounce_rate, :visit_duration, :sample_percent]
      end

    current_results = Stats.aggregate(site, query, metrics)
    prev_results = Stats.aggregate(site, prev_query, metrics)

    stats =
      [
        top_stats_entry(current_results, prev_results, "Unique visitors", :visitors),
        top_stats_entry(current_results, prev_results, "Total pageviews", :pageviews),
        top_stats_entry(current_results, prev_results, "Bounce rate", :bounce_rate),
        top_stats_entry(current_results, prev_results, "Visit duration", :visit_duration),
        top_stats_entry(current_results, prev_results, "Time on page", :time_on_page)
      ]
      |> Enum.filter(& &1)

    {stats, current_results[:sample_percent][:value]}
  end

  defp top_stats_entry(current_results, prev_results, name, key) do
    if current_results[key] do
      %{
        name: name,
        value: current_results[key][:value],
        change: calculate_change(key, prev_results[key][:value], current_results[key][:value])
      }
    end
  end

  defp calculate_change(:bounce_rate, old_count, new_count) do
    if old_count > 0, do: new_count - old_count
  end

  defp calculate_change(_metric, old_count, new_count) do
    percent_change(old_count, new_count)
  end

  defp percent_change(old_count, new_count) do
    cond do
      old_count == 0 and new_count > 0 ->
        100

      old_count == 0 and new_count == 0 ->
        0

      true ->
        round((new_count - old_count) / old_count * 100)
    end
  end

  def sources(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:source", params)

    pagination = parse_pagination(params)

    metrics =
      if params["detailed"], do: [:visitors, :bounce_rate, :visit_duration], else: [:visitors]

    res =
      Stats.breakdown(site, query, "visit:source", metrics, pagination)
      |> transform_keys(%{source: :name})

    json(conn, res)
  end

  def utm_mediums(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_medium", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_medium", metrics, pagination)
      |> transform_keys(%{utm_medium: :name})

    json(conn, res)
  end

  def utm_campaigns(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_campaign", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_campaign", metrics, pagination)
      |> transform_keys(%{utm_campaign: :name})

    json(conn, res)
  end

  def utm_contents(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_content", params)

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_content", metrics, pagination)
      |> transform_keys(%{utm_content: :name})

    json(conn, res)
  end

  def utm_terms(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_term", params)

    pagination = parse_pagination(params)
    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_term", metrics, pagination)
      |> transform_keys(%{utm_term: :name})

    json(conn, res)
  end

  def utm_sources(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> maybe_hide_noref("visit:utm_source", params)

    pagination = parse_pagination(params)

    metrics = [:visitors, :bounce_rate, :visit_duration]

    res =
      Stats.breakdown(site, query, "visit:utm_source", metrics, pagination)
      |> transform_keys(%{utm_source: :name})

    json(conn, res)
  end

  def referrer_drilldown(conn, %{"referrer" => referrer} = params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Query.put_filter("source", referrer)
      |> Filters.add_prefix()

    pagination = parse_pagination(params)

    metrics =
      if params["detailed"], do: [:visitors, :bounce_rate, :visit_duration], else: [:visitors]

    referrers =
      Stats.breakdown(site, query, "visit:referrer", metrics, pagination)
      |> transform_keys(%{referrer: :name})
      |> Enum.map(&Map.drop(&1, [:visits]))

    %{:visitors => %{value: total_visitors}} = Stats.aggregate(site, query, [:visitors])
    json(conn, %{referrers: referrers, total_visitors: total_visitors})
  end

  def pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    metrics =
      if params["detailed"],
        do: [:visitors, :pageviews, :bounce_rate, :time_on_page],
        else: [:visitors]

    pagination = parse_pagination(params)

    pages =
      Stats.breakdown(site, query, "event:page", metrics, pagination)
      |> transform_keys(%{page: :name})

    json(conn, pages)
  end

  def entry_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)
    metrics = [:visitors, :visits, :visit_duration]

    entry_pages =
      Stats.breakdown(site, query, "visit:entry_page", metrics, pagination)
      |> transform_keys(%{
        entry_page: :name,
        visitors: :unique_entrances,
        visits: :total_entrances
      })

    json(conn, entry_pages)
  end

  def exit_pages(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    {limit, page} = parse_pagination(params)
    metrics = [:visitors, :visits]

    exit_pages =
      Stats.breakdown(site, query, "visit:exit_page", metrics, {limit, page})
      |> transform_keys(%{
        exit_page: :name,
        visitors: :unique_exits,
        visits: :total_exits
      })

    pages = Enum.map(exit_pages, & &1[:name])

    total_visits_query =
      Query.put_filter(query, "event:page", {:member, pages})
      |> Query.put_filter("event:goal", nil)
      |> Query.put_filter("event:name", {:is, "pageview"})
      |> Query.put_filter("visit:goal", query.filters["event:goal"])
      |> Query.put_filter("visit:page", query.filters["event:page"])

    total_pageviews =
      Stats.breakdown(site, total_visits_query, "event:page", [:pageviews], {limit, 1})

    exit_pages =
      Enum.map(exit_pages, fn exit_page ->
        exit_rate =
          case Enum.find(total_pageviews, &(&1[:page] == exit_page[:name])) do
            %{pageviews: pageviews} ->
              Float.floor(exit_page[:total_exits] / pageviews * 100)

            nil ->
              nil
          end

        Map.put(exit_page, :exit_rate, exit_rate)
      end)

    json(conn, exit_pages)
  end

  def countries(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:country", {:is_not, "\0\0"})

    pagination = parse_pagination(params)

    countries =
      Stats.breakdown(site, query, "visit:country", [:visitors], pagination)
      |> transform_keys(%{country: :code})
      |> maybe_add_percentages(query)

    countries =
      Enum.map(countries, fn row ->
        country = get_country(row[:code])

        if country do
          Map.merge(row, %{
            name: country.name,
            flag: country.flag,
            alpha_3: country.alpha_3,
            code: country.alpha_2
          })
        else
          Map.merge(row, %{
            name: row[:code],
            flag: "",
            alpha_3: "",
            code: ""
          })
        end
      end)

    json(conn, countries)
  end

  def regions(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:region", {:is_not, ""})

    pagination = parse_pagination(params)

    regions =
      Stats.breakdown(site, query, "visit:region", [:visitors], pagination)
      |> transform_keys(%{region: :code})
      |> Enum.map(fn region ->
        region_entry = Location.get_subdivision(region[:code])

        if region_entry do
          country_entry = get_country(region_entry.country_code)
          Map.merge(region, %{name: region_entry.name, country_flag: country_entry.flag})
        else
          Sentry.capture_message("Could not find region info", extra: %{code: region[:code]})
          Map.merge(region, %{name: region[:code]})
        end
      end)

    json(conn, regions)
  end

  def cities(conn, params) do
    site = conn.assigns[:site]

    query =
      Query.from(site, params)
      |> Filters.add_prefix()
      |> Query.put_filter("visit:city", {:is_not, 0})

    pagination = parse_pagination(params)

    cities =
      Stats.breakdown(site, query, "visit:city", [:visitors], pagination)
      |> transform_keys(%{city: :code})
      |> Enum.map(fn city ->
        city_info = Location.get_city(city[:code])

        if city_info do
          country_info = get_country(city_info.country_code)

          Map.merge(city, %{
            name: city_info.name,
            country_flag: country_info.flag
          })
        else
          Sentry.capture_message("Could not find city info", extra: %{code: city[:code]})

          Map.merge(city, %{name: "N/A"})
        end
      end)

    json(conn, cities)
  end

  def browsers(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    browsers =
      Stats.breakdown(site, query, "visit:browser", [:visitors], pagination)
      |> transform_keys(%{browser: :name})
      |> maybe_add_percentages(query)

    json(conn, browsers)
  end

  def browser_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    versions =
      Stats.breakdown(site, query, "visit:browser_version", [:visitors], pagination)
      |> transform_keys(%{browser_version: :name})
      |> maybe_add_percentages(query)

    json(conn, versions)
  end

  def operating_systems(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    systems =
      Stats.breakdown(site, query, "visit:os", [:visitors], pagination)
      |> transform_keys(%{os: :name})
      |> maybe_add_percentages(query)

    json(conn, systems)
  end

  def operating_system_versions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    versions =
      Stats.breakdown(site, query, "visit:os_version", [:visitors], pagination)
      |> transform_keys(%{os_version: :name})
      |> maybe_add_percentages(query)

    json(conn, versions)
  end

  def screen_sizes(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()
    pagination = parse_pagination(params)

    sizes =
      Stats.breakdown(site, query, "visit:device", [:visitors], pagination)
      |> transform_keys(%{device: :name})
      |> maybe_add_percentages(query)

    json(conn, sizes)
  end

  def current_visitors(conn, _) do
    site = conn.assigns[:site]
    json(conn, Stats.current_visitors(site))
  end

  def handle_errors(conn, %{kind: kind, reason: reason}) do
    json(conn, %{error: Exception.format_banner(kind, reason)})
  end

  def filter_suggestions(conn, params) do
    site = conn.assigns[:site]
    query = Query.from(site, params) |> Filters.add_prefix()

    json(conn, Stats.filter_suggestions(site, query, params["filter_name"], params["q"]))
  end

  defp transform_keys(results, keys_to_replace) do
    Enum.map(results, fn map ->
      Enum.map(map, fn {key, val} ->
        {Map.get(keys_to_replace, key, key), val}
      end)
      |> Enum.into(%{})
    end)
  end

  defp parse_pagination(params) do
    limit = if params["limit"], do: String.to_integer(params["limit"]), else: 9
    page = if params["page"], do: String.to_integer(params["page"]), else: 1
    {limit, page}
  end

  defp maybe_add_percentages(stat_list, query) do
    if Map.has_key?(query.filters, "event:goal") do
      stat_list
    else
      total = Enum.reduce(stat_list, 0, fn %{visitors: count}, total -> total + count end)

      Enum.map(stat_list, fn stat ->
        Map.put(stat, :percentage, round(stat[:visitors] / total * 100))
      end)
    end
  end

  defp maybe_hide_noref(query, property, params) do
    cond do
      is_nil(query.filters[property]) and params["show_noref"] != "true" ->
        new_filters = Map.put(query.filters, property, {:is_not, "Direct / None"})
        %Query{query | filters: new_filters}

      true ->
        query
    end
  end

  defp get_country(code) do
    case Location.get_country(code) do
      nil ->
        Sentry.capture_message("Could not find country info", extra: %{code: code})

        %Location.Country{
          alpha_2: code,
          alpha_3: "N/A",
          name: code,
          flag: nil
        }

      country ->
        country
    end
  end
end
