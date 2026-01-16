defmodule Plausible.Stats.CurrentVisitors do
  use Plausible.ClickhouseRepo
  use Plausible.Stats.Fragments

  def current_visitors(_) do
    from_datetime =
      NaiveDateTime.utc_now()
      |> Timex.shift(minutes: -5)

    to_datetime = NaiveDateTime.utc_now()

    ClickhouseRepo.one(
      from e in "events",
        where: e.timestamp >= ^from_datetime and e.timestamp <= ^to_datetime,
        select: uniq(e.user_id)
    )
  end
end
