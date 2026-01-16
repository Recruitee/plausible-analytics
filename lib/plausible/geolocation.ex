defmodule Plausible.Geolocation do
  @moduledoc """
  Behaviour for geolocation lookup services.

  This behaviour defines the interface for looking up geographic information
  based on IP addresses. Implementations can use different geolocation databases
  or services.
  """

  @type ip_address :: String.t() | :inet.ip_address()
  @type geo_data :: map()
  @type lookup_result :: {:ok, geo_data()} | {:error, atom()}

  @doc """
  Looks up geographic information for the given IP address.

  ## Parameters

    * `ip` - The IP address to look up, either as a string or tuple

  ## Returns

    * `{:ok, geo_data}` - A map containing geographic information
    * `{:error, reason}` - An error tuple if lookup fails
  """
  @callback lookup(ip_address()) :: lookup_result()

  def lookup(ip), do: impl().lookup(ip)

  defp impl, do: Application.get_env(:plausible, :geolocation, Plausible.Geolocation.Locus)
end
