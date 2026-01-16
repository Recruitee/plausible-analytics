defmodule Plausible.Stats.Aggregate do
  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  @event_metrics [:visitors, :pageviews, :events, :sample_percent]
  @session_metrics [:visits, :bounce_rate, :visit_duration, :sample_percent]

  def aggregate(site, query, metrics) do
    event_metrics = Enum.filter(metrics, &(&1 in @event_metrics))
    event_task = Task.async(fn -> aggregate_events(site, query, event_metrics) end)
    session_metrics = Enum.filter(metrics, &(&1 in @session_metrics))
    session_task = Task.async(fn -> aggregate_sessions(site, query, session_metrics) end)

    Task.await(session_task, 10_000)
    |> Map.merge(Task.await(event_task, 10_000))
    |> Enum.map(fn {metric, value} ->
      {metric, %{value: round(value || 0)}}
    end)
    |> Enum.into(%{})
  end

  defp aggregate_events(_, _, []), do: %{}

  defp aggregate_events(site, query, metrics) do
    from(e in base_event_query(site, query), select: %{})
    |> select_event_metrics(metrics)
    |> ClickhouseRepo.one()
  end

  defp aggregate_sessions(_, _, []), do: %{}

  defp aggregate_sessions(site, query, metrics) do
    query = Query.treat_page_filter_as_entry_page(query)

    from(e in query_sessions(site, query), select: %{})
    |> select_session_metrics(metrics)
    |> ClickhouseRepo.one()
  end
end
