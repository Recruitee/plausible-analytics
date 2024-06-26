defmodule Mix.Tasks.DownloadCountryDatabase do
  use Mix.Task
  use Plausible.Repo
  require Logger

  # coveralls-ignore-start

  def run(_) do
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:timex)
    this_month = Timex.today()
    last_month = Timex.shift(this_month, months: -1)
    this_month = this_month |> Date.to_iso8601() |> binary_part(0, 7)
    last_month = last_month |> Date.to_iso8601() |> binary_part(0, 7)
    this_month_url = "https://download.db-ip.com/free/dbip-country-lite-#{this_month}.mmdb.gz"
    last_month_url = "https://download.db-ip.com/free/dbip-country-lite-#{last_month}.mmdb.gz"
    Logger.info("Downloading #{this_month_url}")
    res = HTTPoison.get!(this_month_url)

    res =
      case res.status_code do
        404 ->
          Logger.info("Got 404 for #{this_month_url}, trying #{last_month_url}")
          HTTPoison.get!(last_month_url)

        _ ->
          res
      end

    if res.status_code == 200 do
      File.mkdir(geodb_dir_path())
      File.write!(geodb_file_path(), res.body)
      Logger.info("Downloaded and saved the database successfully")
    else
      Logger.error("Unable to download and save the database. Response: #{inspect(res)}")
    end
  end

  defp geodb_dir_path do
    geodb_file_path()
    |> String.split("/")
    |> List.pop_at(-1)
    |> then(fn {_, elements} -> Enum.join(elements, "/") end)
  end

  defp geodb_file_path do
    default_file_path = "geodb/dbip-country.mmdb"

    with [%{source: path} | _] <- Application.get_env(:geolix, :databases) do
      path
    else
      _ -> default_file_path
    end
  end
end
